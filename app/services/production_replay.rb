module ProductionReplay
  HOST = "gaming.harvj.com"

  def self.enabled?
    Rails.env.production? && !ModernArtStaging.enabled? && ENV["REMOTE_GAMING_PRODUCTION_REPLAY"] == "1"
  end

  def self.validate_oidc!
    unless CanonicalAuth.enabled? && ENV["REMOTE_GAMING_OIDC_ISSUER"] == "https://auth.harvj.com" &&
        ENV["REMOTE_GAMING_OIDC_REDIRECT_URI"] == "https://#{HOST}/auth/callback"
      raise "Production requires its own Auth registration"
    end

    CanonicalAuth.new
  end
end
