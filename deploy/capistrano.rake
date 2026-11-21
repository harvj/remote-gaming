require "tempfile"

def remote_gaming_verify_helper
  expected = Digest::SHA256.file("deploy/remote-gaming-deploy").hexdigest
  actual = capture(:sudo, "-n", RemoteGamingDeployment.helper(fetch(:stage)), "version").strip
  raise "Installed Remote Gaming deployment helper differs from the reviewed local file" unless actual == expected
end

namespace :deploy do
  desc "Print selected deployment target without connecting"
  task :config do
    puts "#{fetch(:stage)} #{fetch(:application)} #{fetch(:deploy_to)}"
  end

  desc "Verify the installed target locally and on Hetzner without deployment"
  task :check do
    on roles(:app) do
      remote_gaming_verify_helper
      execute :sudo, "-n", RemoteGamingDeployment.helper(fetch(:stage)), "check", fetch(:stage)
    end
  end

  desc "Switch to the approved immediately previous release if the database schema is compatible"
  task :rollback do
    revision = RemoteGamingDeployment.approved!(ENV["APPROVED_COMMIT"], rollback: true)
    on roles(:app) do
      remote_gaming_verify_helper
      execute :sudo, "-n", RemoteGamingDeployment.helper(fetch(:stage)), "rollback", fetch(:stage), revision
    end
  end
end

desc "Deploy the reviewed GitHub main commit to the selected Remote Gaming environment"
task :deploy do
  revision = RemoteGamingDeployment.approved!(ENV["APPROVED_COMMIT"])
  migrations = ENV.fetch("ALLOW_MIGRATIONS", "0")
  raise "ALLOW_MIGRATIONS must be 0 or 1" unless %w[0 1].include?(migrations)

  Tempfile.create([ "remote-gaming", ".tar.gz" ]) do |archive|
    RemoteGamingDeployment.command("git", "archive", "--format=tar.gz", "--output=#{archive.path}", revision)
    checksum = Digest::SHA256.file(archive.path).hexdigest
    RemoteGamingDeployment.verify_artifact!(archive.path, revision, checksum)
    if fetch(:stage).to_s == "production"
      RemoteGamingDeployment.verify_shell!(revision)
    end

    on roles(:app) do
      remote_gaming_verify_helper
      execute :sudo, "-n", RemoteGamingDeployment.helper(fetch(:stage)), "check", fetch(:stage)
      directory = capture(:mktemp, "-d", "/tmp/remote-gaming-cap.XXXXXXXX").strip
      raise "Unexpected upload directory" unless directory.match?(%r{\A/tmp/remote-gaming-cap\.[a-zA-Z0-9]{8}\z})

      begin
        upload! archive.path, "#{directory}/release.tar.gz"
        execute :sudo, "-n", RemoteGamingDeployment.helper(fetch(:stage)), "deploy", fetch(:stage), revision, checksum, migrations,
          "#{directory}/release.tar.gz"
      ensure
        execute :rm, "-f", "--", "#{directory}/release.tar.gz"
        execute :rmdir, "--", directory
      end
    end
  end
end
