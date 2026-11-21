class ShellApplicationsController < ApplicationController
  skip_before_action :load_game

  def show
    response.headers["Cache-Control"] = "no-store"
    return head :not_found unless CanonicalAuth.enabled? && !session.key?(:dummy_browser)

    login = AuthLogin.authorized(session[:oidc_login])
    return head :unauthorized unless login

    evidence = CanonicalAuth.new.shell_evidence(login.grant_token, login.auth_identity.subject, login.expires_at)
    return render json: { applications: [], expires_in_ms: 0 } unless evidence

    applications = ShellRegistry.destinations(evidence.fetch("eligible_destination_ids"))
    remaining = (1_000 * (evidence.fetch("exp") - Time.current.to_f)).floor
    render json: { applications: remaining.positive? ? applications : [], expires_in_ms: [ remaining, 0 ].max }
  rescue CanonicalAuth::InvalidLogin, ActiveSupport::MessageEncryptor::InvalidMessage
    head :service_unavailable
  end
end
