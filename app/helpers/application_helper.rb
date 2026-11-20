module ApplicationHelper
  def navigation_login_url
    if ModernArtStaging.enabled? && CanonicalAuth.enabled?
      path = login_path(return_to: NavigationLogin.return_path(request.path) || "/")
      request.host == ModernArtStaging::GAME_HOST ? path : "https://#{ModernArtStaging::GAME_HOST}#{path}"
    elsif ProductionReplay.enabled?
      request.host == ProductionReplay::HOST ? login_path : "https://#{ProductionReplay::HOST}#{login_path}"
    elsif HistoricalUserAdministration.enabled?
      path = historical_admin_auth_path
      request.host == HistoricalUserAdministration::HOST ? path : "https://#{HistoricalUserAdministration::HOST}#{path}"
    elsif !Rails.env.production? && CanonicalAuth.enabled?
      auth_start_path(return_to: NavigationLogin.return_path(request.path))
    else
      NavigationLogin::AUTH_URL
    end
  end
end
