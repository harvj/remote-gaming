class UserConfigsController < ApplicationController
  before_action :authenticate_user!

  def update
    raise ActiveRecord::RecordNotFound unless current_user.username == params[:user_id]

    user = current_user
    if user.config.update(config_params)
      render json: { status: "success", content: { user: Representers::User.(user.reload) }, errors: [] }
    end
  end

  private

  def config_params
    params.require(:config).permit(:show_all_badges, :show_badge_values)
  end
end
