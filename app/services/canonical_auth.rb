require "net/http"

class CanonicalAuth
  class InvalidLogin < StandardError; end

  PASSWORD = "urn:harvj:assurance:password"
  MFA = "urn:harvj:assurance:mfa"
  LOGIN_SECONDS = 600
  SESSION_SECONDS = 8.hours.to_i

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
    if ModernArtStaging.enabled? && @redirect_uri != "https://#{ModernArtStaging::GAME_HOST}/auth/callback"
      raise InvalidLogin
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
    query = URI.encode_www_form(client_id: @client_id, redirect_uri: @redirect_uri, response_type: "code",
      scope: "openid", state: attempt.fetch("state"), nonce: attempt.fetch("nonce"),
      code_challenge_method: "S256", code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(attempt.fetch("verifier")), padding: false))
    "#{@issuer}/authorize?#{query}"
  end

  def authenticate(attempt, state:, code:)
    unless attempt && attempt.fetch("expires") > Time.current.to_i && state.is_a?(String) &&
        ActiveSupport::SecurityUtils.secure_compare(attempt.fetch("state"), state) && code.is_a?(String) && code.present?
      raise InvalidLogin
    end

    uri = URI("#{@issuer}/token")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(URI.encode_www_form_component(@client_id), URI.encode_www_form_component(@client_secret))
    request.set_form_data(grant_type: "authorization_code", code: code, redirect_uri: @redirect_uri,
      code_verifier: attempt.fetch("verifier"))
    token = fetch_json(uri, request)["id_token"]
    raise InvalidLogin unless token.is_a?(String) && token.present?

    jwks_uri = URI("#{@issuer}/jwks")
    jwks = fetch_json(jwks_uri, Net::HTTP::Get.new(jwks_uri))
    raise InvalidLogin unless jwks["keys"].is_a?(Array) && jwks["keys"].all?(Hash)

    claims = verify(token, jwks, attempt)
    identity = AuthIdentity.find_by!(issuer: claims.fetch("iss"), subject: claims.fetch("sub"))
    [ identity, claims.fetch("acr") ]
  rescue JWT::DecodeError, KeyError, JSON::ParserError, ActiveRecord::RecordNotFound,
      IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
    raise InvalidLogin, cause: nil
  end

  private

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
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 4) do |http|
      http.request(request)
    end
    raise InvalidLogin unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    raise InvalidLogin unless data.is_a?(Hash)

    data
  end
end
