class ModernArtPracticeChannel < ApplicationCable::Channel
  def subscribed
    return reject unless connection.practice_owner?

    table = ModernArtPracticeTable.find_by(uid: params[:uid], owner: current_user)
    return reject unless table

    stream_for table, coder: ActiveSupport::JSON do |payload|
      transmit(payload) if connection.practice_owner?
    end
  end
end
