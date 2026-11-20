class Users::SessionsController < Devise::SessionsController
  def new
    head :not_found
  end

  def create
    head :not_found
  end

  def destroy
    if CanonicalAuth.enabled?
      AuthLogin.end_session(session[:oidc_login])
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
