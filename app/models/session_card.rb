class SessionCard < ApplicationRecord
  belongs_to :session, class_name: 'GameSession', foreign_key: 'game_session_id'
  belongs_to :session_deck
  belongs_to :card
  belongs_to :player, optional: true

  scope :dealt,       -> { where('dealt_at IS NOT NULL') }
  scope :undealt,     -> { where('dealt_at IS NULL') }
  scope :played,      -> { where('played_at IS NOT NULL') }
  scope :discarded,   -> { where('discarded_at IS NOT NULL') }
  scope :shuffled,    -> { order('random()') }
  scope :active,      -> { dealt.where('discarded_at IS NULL AND played_at IS NULL') }
  scope :inactive,    -> { dealt.where('discarded_at IS NOT NULL OR played_at IS NOT NULL') }
  scope :by_card_key, ->(key) { joins(:card).where("cards.key = ?", key) }
  scope :by_deck_key, ->(key) { joins(:session_deck).where("session_decks.key = ?", key) }

  # --- Actions

  def deal(player=nil)
    SessionCard.transaction do
      update_attributes(
        dealt_at: Time.zone.now,
        player: player
      )
      SessionFrame::Create.(session,
        action: 'card_dealt',
        affected_player: player,
        subject: self
      )
      session.game_play.card_dealt(self)
      # raise 'foo'
    end
  end

  def play(affected_player=nil)
    SessionCard.transaction do
      return unless playable?
      update_attribute(:played_at, Time.zone.now)
      SessionFrame::Create.(session,
        action: 'card_played',
        acting_player: player,
        affected_player: affected_player,
        subject: self
      )
      session.game_play.card_played(self)
    end
  end

  def discard(player=nil)
    SessionCard.transaction do
      return unless discardable?
      update_attribute(:discarded_at, Time.zone.now)
      SessionFrame::Create.(session,
        action: 'card_discarded',
        acting_player: player,
        subject: self
      )
      session.game_play.card_discarded(self)
    end
  end

  # --- Attributes

  def status
    return 'deck' if !dealt?
    return 'played' if played?
    return 'active' if active?
    return 'playable' if playable?
    return 'discarded' if discarded?
    'unplayable'
  end

  def active?
    dealt? && !(played? || discarded?)
  end

  def dealt?
    dealt_at.present?
  end

  def dealt_at_milli
    return unless dealt?
    dealt_at.to_datetime.strftime('%Q').to_i
  end

  def dealt_during_state
    session.frames.find_by(subject: self, action: 'card_dealt')&.state
  end

  def played?
    played_at.present?
  end

  def played_at_milli
    return unless played?
    played_at.to_datetime.strftime('%Q').to_i
  end

  def discarded?
    discarded_at.present?
  end

  def discarded_at_milli
    return unless discarded?
    discarded_at.to_datetime.strftime('%Q').to_i
  end

  # --- Session specific attributes

  def valid_action
    return 'discard' if discardable?
    return 'play' if playable?
    return session.game_play.card_valid_action(self)
  end

  def playable?
    active? && session.game_play.card_playable?(self)
  end

  def playable_out_of_turn?
    session.game_play.card_playable_out_of_turn?(self)
  end

  def discardable?
    !discarded? && session.game_play.card_discardable?(self)
  end

  def tradeable?
    session.game_play.card_tradeable?(self)
  end
end
