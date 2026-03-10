class ApplicationController < ActionController::Base
  protect_from_forgery

  # before_action :require_user
  before_action :load_game
  before_action :set_session_flash
  before_action :init_common_data

  def init_common_data
    @common_data = {
      currentUser: Representers::User.(current_user),
      loggedIn: current_user.present?,
      paths: Representers::Paths.(),
      token: form_authenticity_token
    }
  end

  def require_user
    redirect_to login_path and return unless current_user.present?
  end

  def set_session_flash
    if current_user.present?
      flash[:info] = "Logged in as <a href='#{user_path(current_user)}'>#{current_user.username}</a>" if current_user.present?
    else
      flash[:warning] = "Not signed in."
    end
  end

  private

  def load_game
    Rails.logger.info "SUBDOMAIN: #{request.subdomain.inspect}"
    @game = Game.find_by(slug: request.subdomain)
  end
end
