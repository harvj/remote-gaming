module ExperimentalAccess
  def self.enabled?
    ModernArtStaging.enabled? && CanonicalAuth.enabled?
  end
end
