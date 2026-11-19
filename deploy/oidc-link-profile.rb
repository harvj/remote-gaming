# The subject must come from a verified Auth authentication response for this client.
abort "Configure the approved OIDC issuer first" unless CanonicalAuth.enabled?

profile = User.find(Integer(ENV.fetch("RG_PROFILE_ID"), 10))
operation = ENV.fetch("RG_LINK_OPERATION", "link")
ReconcileAuthIdentity.call(profile: profile, issuer: ENV.fetch("REMOTE_GAMING_OIDC_ISSUER"),
  subject: ENV.fetch("RG_VERIFIED_SUBJECT"), evidence: ENV.fetch("RG_EVIDENCE_REFERENCE"), operation: operation)
puts "Identity reconciliation recorded for local profile #{profile.id}"
