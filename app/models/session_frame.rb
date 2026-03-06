class SessionFrame < ApplicationRecord
  belongs_to :game_session

  belongs_to :acting_player, class_name: 'Player', optional: true
  belongs_to :affected_player, class_name: 'Player', optional: true
  belongs_to :subject, polymorphic: true
  belongs_to :previous_frame, class_name: 'SessionFrame', optional: true

  validates :action, presence: true

  scope :card_played, -> { where(action: 'card_played') }

  def created_at_milli
    created_at.to_datetime.strftime('%Q').to_i
  end
end
