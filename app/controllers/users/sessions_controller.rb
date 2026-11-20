class Users::SessionsController < Devise::SessionsController
  def new
    if CanonicalAuth.enabled?
      redirect_to auth_start_path
    else
      redirect_to NavigationLogin::AUTH_URL, allow_other_host: true
    end
  end

  def create
    head :not_found
  end

  def destroy
    if CanonicalAuth.enabled?
      AuthLogin.authorized(session[:oidc_login])&.destroy!
      reset_session
      destination = ModernArtStaging.enabled? ? staging_signed_out_path : login_path
      return redirect_to destination, status: :see_other
    end

    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    respond_to_on_destroy
  end

  private

  def verify_signed_out_user
    super unless CanonicalAuth.enabled?
  end
end
