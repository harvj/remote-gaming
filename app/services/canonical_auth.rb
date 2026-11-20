require "net/http"

class CanonicalAuth
  class InvalidLogin < StandardError; end

  class Client < OpenIDConnect::Client
    private

    def handle_success_response(response)
      body = response.body
      unless body.is_a?(Hash) && %w[id_token access_token].all? { |key| body[key].is_a?(String) && body[key].present? } &&
          body["expires_in"].is_a?(Integer) && body["expires_in"].positive? &&
          body["token_type"].to_s.casecmp?("bearer")
        raise InvalidLogin
      end

      super
    end
  end
  private_constant :Client

  PASSWORD = "urn:harvj:assurance:password"
  MFA = "urn:harvj:assurance:mfa"
  LOGIN_SECONDS = 600
  SESSION_SECONDS = 5.minutes.to_i

  def self.enabled?
    ENV.key?("REMOTE_GAMING_OIDC_ISSUER")
  end

  def initialize
    @issuer = ENV.fetch("REMOTE_GAMING_OIDC_ISSUER")
    @client_id = ENV.fetch("REMOTE_GAMING_OIDC_CLIENT_ID")
    @client_secret = ENV.fetch("REMOTE_GAMING_OIDC_CLIENT_SECRET")
    @redirect_uri = ENV.fetch("REMOTE_GAMING_OIDC_REDIRECT_URI")
    issuer_uri = https_uri(@issuer)
    callback_uri = https_uri(@redirect_uri)
    if ModernArtStaging.enabled?
      unless @issuer == "https://auth.harvj.com" && @redirect_uri == "https://#{ModernArtStaging::GAME_HOST}/auth/callback" &&
          ModernArtStaging.owner_subject.to_s.match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/) &&
          ModernArtStaging::OWNER_EVIDENCE_FORMAT.match?(ModernArtStaging.owner_evidence.to_s)
        raise InvalidLogin
      end
    end
    if Rails.env.production? && !ModernArtStaging.enabled?
      raise InvalidLogin unless @issuer == "https://auth.harvj.com" && @redirect_uri == "https://#{ProductionReplay::HOST}/auth/callback"
    end
    unless issuer_uri.path.empty? && callback_uri.path == "/auth/callback" &&
        @client_id.present? && @client_secret.present?
      raise InvalidLogin
    end
  rescue KeyError, URI::InvalidURIError
    raise InvalidLogin, cause: nil
  end

  def start
    {
      "state" => SecureRandom.urlsafe_base64(32), "nonce" => SecureRandom.urlsafe_base64(32),
      "verifier" => SecureRandom.urlsafe_base64(32), "expires" => Time.current.to_i + LOGIN_SECONDS
    }
  end

  def authorization_url(attempt)
    oidc_client.authorization_uri(scope: %w[openid], state: attempt.fetch("state"), nonce: attempt.fetch("nonce"),
      code_challenge_method: "S256", code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(attempt.fetch("verifier")), padding: false))
  end

  def active_access_token?(token)
    result = fetch_json(URI("#{@issuer}/introspect"), token_request("introspect", token))
    result["active"] == true && (!result.key?("client_id") || result["client_id"] == @client_id)
  end

  def revoke(token)
    uri = URI("#{@issuer}/revoke")
    perform_http(uri, token_request("revoke", token))
  end

  def authenticate(attempt, state:, code:)
    unless attempt && attempt.fetch("expires") > Time.current.to_i && state.is_a?(String) &&
        ActiveSupport::SecurityUtils.secure_compare(attempt.fetch("state"), state) && code.is_a?(String) && code.present?
      raise InvalidLogin
    end

    client = oidc_client
    client.authorization_code = code
    tokens = client.access_token!(:basic, code_verifier: attempt.fetch("verifier")) do |request|
      request.options.open_timeout = 4
      request.options.timeout = 4
    end
    token, access, seconds = tokens.id_token, tokens.access_token, tokens.expires_in

    jwks_uri = URI(provider_metadata.fetch("jwks_uri"))
    jwks = fetch_json(jwks_uri, Net::HTTP::Get.new(jwks_uri))
    raise InvalidLogin unless jwks["keys"].is_a?(Array) && jwks["keys"].all?(Hash)

    claims = verify(token, jwks, attempt)
    raise InvalidLogin unless active_access_token?(access)

    identity = if ModernArtStaging.enabled?
      staging_identity(claims.fetch("sub"))
    else
      AuthIdentity.active.find_by!(issuer: claims.fetch("iss"), subject: claims.fetch("sub"))
    end
    [ identity, claims.fetch("acr"), access, [ seconds, SESSION_SECONDS ].min ]
  rescue Rack::OAuth2::Client::Error, Faraday::Error, JWT::DecodeError, KeyError, JSON::ParserError, ActiveRecord::RecordNotFound,
      IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
    raise InvalidLogin, cause: nil
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ReconcileAuthIdentity::Conflict
    raise InvalidLogin, cause: nil
  end

  private

  def oidc_client
    Client.new(identifier: @client_id, secret: @client_secret, redirect_uri: @redirect_uri,
      authorization_endpoint: provider_metadata.fetch("authorization_endpoint"),
      token_endpoint: provider_metadata.fetch("token_endpoint"))
  end

  def provider_metadata
    @provider_metadata ||= begin
      uri = URI("#{@issuer}/.well-known/openid-configuration")
      metadata = fetch_json(uri, Net::HTTP::Get.new(uri))
      expected = { "issuer" => @issuer, "authorization_endpoint" => "#{@issuer}/authorize",
        "token_endpoint" => "#{@issuer}/token", "jwks_uri" => "#{@issuer}/jwks" }
      raise InvalidLogin unless expected.all? { |key, value| metadata[key] == value }

      metadata
    end
  end

  def token_request(endpoint, token)
    request = Net::HTTP::Post.new(URI("#{@issuer}/#{endpoint}"))
    request.basic_auth(URI.encode_www_form_component(@client_id), URI.encode_www_form_component(@client_secret))
    request.set_form_data(token: token, token_type_hint: "access_token")
    request
  end

  def staging_identity(subject)
    raise InvalidLogin unless subject == ModernArtStaging.owner_subject

    owner = User.find(ModernArtStaging::OWNER_PROFILE_ID)
    owner.with_lock do
      raise InvalidLogin unless owner.username == "jim" && !owner.dummy?

      identity = AuthIdentity.find_by(user: owner)
      if identity
        raise InvalidLogin unless identity.issuer == @issuer && identity.subject == subject && !identity.revoked_at?
        return identity
      end

      raise InvalidLogin unless owner.players.count == 83

      ReconcileAuthIdentity.call(profile: owner, issuer: @issuer, subject: subject,
        evidence: ModernArtStaging.owner_evidence, operation: "link")
    end
  end

  def https_uri(url)
    uri = URI.parse(url)
    raise InvalidLogin unless uri.is_a?(URI::HTTPS) && uri.host.present? && !uri.userinfo && !uri.query && !uri.fragment

    uri
  end

  def verify(token, jwks, attempt)
    claims, = JWT.decode(token, nil, true, algorithms: [ "RS256" ], jwks: jwks,
      verify_iss: true, iss: @issuer, verify_aud: true, aud: @client_id,
      required_claims: %w[iss sub aud exp iat nonce acr])
    unless claims["nonce"] == attempt.fetch("nonce") && claims["sub"].is_a?(String) && claims["sub"].present? &&
        Array(claims["aud"]) == [ @client_id ] && claims.fetch("azp", @client_id) == @client_id &&
        claims["exp"].is_a?(Integer) && claims["exp"] > Time.current.to_i &&
        claims["iat"].is_a?(Integer) && claims["iat"].between?(Time.current.to_i - LOGIN_SECONDS, Time.current.to_i + 30) &&
        [ PASSWORD, MFA ].include?(claims["acr"])
      raise InvalidLogin
    end

    claims
  end

  def fetch_json(uri, request)
    response = perform_http(uri, request)
    raise InvalidLogin unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    raise InvalidLogin unless data.is_a?(Hash)

    data
  rescue JSON::ParserError
    raise InvalidLogin, cause: nil
  end

  def perform_http(uri, request)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 4) do |http|
      http.request(request)
    end
  rescue IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
    raise InvalidLogin, cause: nil
  end
end
