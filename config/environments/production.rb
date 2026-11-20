require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local
  config.active_storage.draw_routes = false

  # Puma listens on loopback behind the HTTPS reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Keep deployment probe output on stdout and route Rails diagnostics to stderr.
  config.log_tags = [ :request_id ]
  log_output = ENV["REMOTE_GAMING_DEPLOY_TASK"] == "1" ? STDERR : STDOUT
  config.logger = ActiveSupport::TaggedLogging.logger(log_output)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # The public directory needs no persistent cache or live gameplay.
  config.cache_store = :memory_store
  config.action_cable.mount_path = nil

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "radioactivita.com" }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  config.hosts = [ "radioactivita.com", "gaming.harvj.com", /[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.radioactivita\.com/ ]

  config.after_initialize { ProductionReplay.validate_oidc! if ProductionReplay.enabled? }
  if ENV["REMOTE_GAMING_PRODUCTION_REPLAY"] == "1" && !ModernArtStaging.enabled?
    config.session_store :cookie_store, key: "__Host-remote_gaming_replay", secure: true, same_site: :lax
  end

  if ENV["REMOTE_GAMING_HISTORICAL_ADMIN"] == "1" && !ModernArtStaging.enabled?
    config.after_initialize { HistoricalUserAdministration.validate! }
    unless ENV["REMOTE_GAMING_PRODUCTION_REPLAY"] == "1"
      config.session_store :cookie_store, key: "__Host-remote_gaming_admin", secure: true, same_site: :lax
    end
  end

  if ModernArtStaging.enabled?
    ModernArtStaging.validate!
    config.action_mailer.delivery_method = :test
    config.action_mailer.perform_deliveries = false
    config.after_initialize { CanonicalAuth.new }
    config.hosts = ModernArtStaging::HOSTS
    config.action_cable.mount_path = "/cable"
    config.action_cable.allowed_request_origins = [ "https://#{ModernArtStaging::GAME_HOST}" ]
    config.action_cable.allow_same_origin_as_host = false
    config.session_store :cookie_store, key: "__Host-remote_gaming_staging", secure: true, same_site: :lax
  end
end
