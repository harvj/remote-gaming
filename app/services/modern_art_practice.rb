module ModernArtPractice
  def self.enabled_on?(host)
    ENV["REMOTE_GAMING_MODERN_ART_PRACTICE"] == "1" &&
      ModernArtStaging.enabled? && CanonicalAuth.enabled? && host == ModernArtStaging::GAME_HOST
  end

  def self.owner?(host, user)
    enabled_on?(host) && user&.id == ModernArtStaging::OWNER_PROFILE_ID && !user.dummy?
  end
end
