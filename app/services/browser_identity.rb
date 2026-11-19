class BrowserIdentity
  def self.oidc_user(session)
    AuthLogin.authorized(session[:oidc_login])&.auth_identity&.user unless session[:oidc_login].nil?
  end
end
