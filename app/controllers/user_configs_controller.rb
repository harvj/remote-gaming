class UserConfigsController < ApplicationController
  def update
    user = User.find_by(username: params[:user_id]) || not_found
    if user.config.update(config_params)
      render json: { status: 'success', content: { user: Representers::User.(user.reload) }, errors: [] }
    end
  end

  private

  def config_params
    params.require(:config).permit(:show_all_badges, :show_badge_values)
  end
end
