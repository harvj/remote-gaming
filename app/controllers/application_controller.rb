class ApplicationController < ActionController::Base
  protect_from_forgery

  before_action :load_game

  private

  def load_game
    Rails.logger.info "SUBDOMAIN: #{request.subdomain.inspect}"
    @game = Game.find_by(slug: request.subdomain)
  end
end
