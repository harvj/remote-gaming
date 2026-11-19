class Users::SessionsController < Devise::SessionsController
  # skip_before_action :require_user, only: %i[new create]
  before_action :init_common_data, only: %i[new create]

  def create
    return head :not_found if CanonicalAuth.enabled?

    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)
    respond_with resource, location: after_sign_in_path_for(resource)
  end

  def destroy
    if CanonicalAuth.enabled?
      AuthLogin.authorized(session[:oidc_login])&.destroy!
      reset_session
      return redirect_to login_path, status: :see_other
    end

    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    respond_to_on_destroy
  end

  private

  def verify_signed_out_user
    super unless CanonicalAuth.enabled?
  end

  def init_common_data
    @common_data = {
      paths: Representers::Paths.(),
      token: form_authenticity_token
    }
  end
end
