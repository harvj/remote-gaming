# Resolve the running release at boot, before a later deploy can switch current.
release = Rails.root.realpath
revision = release.basename.to_s
label = "development"

if release.parent.basename.to_s == "releases" && revision.match?(/\A[0-9a-f]{40}\z/)
  label = revision[0, 12]
  version_file = release.join(".release-version")
  if version_file.file?
    stamped_revision, tag = version_file.read.split
    label = tag if stamped_revision == revision && tag&.match?(/\Av0\.\d+\.\d+\z/)
  end
end

Rails.application.config.x.directory_release_label = "Remote Gaming #{label}".freeze
