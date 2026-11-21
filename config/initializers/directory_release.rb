require Rails.root.join("lib/remote_gaming_release_identity")

stage = ENV["REMOTE_GAMING_PRIVATE_STAGING"] == "1" ? "staging" : "production"
receipts = Pathname("/var/lib/remote-gaming-shell-#{stage}/publications")
Rails.application.config.x.directory_release = RemoteGamingReleaseIdentity.new(
  Rails.root, receipts: receipts, development_version: "0.4.3"
)
