# Run only after an operator has verified the evidence and profile ownership.
abort "Configure the approved OIDC issuer first" unless CanonicalAuth.enabled?

profile = User.find(Integer(ENV.fetch("RG_PROFILE_ID"), 10))
link = AuthIdentity.find_or_create_by!(issuer: ENV.fetch("REMOTE_GAMING_OIDC_ISSUER"),
  subject: ENV.fetch("RG_VERIFIED_SUBJECT"), user: profile) do |identity|
  identity.evidence_reference = ENV.fetch("RG_EVIDENCE_REFERENCE")
end
abort "Existing evidence differs; review the recorded decision" unless link.evidence_reference == ENV.fetch("RG_EVIDENCE_REFERENCE")
puts "Verified identity link: local profile #{profile.id}"
