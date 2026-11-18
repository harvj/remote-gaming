class Games::ModernArt::Observations
  FIELDS = {
    "auction_result" => %w[card_id buyer_id winning_bid],
    "payment" => %w[payer_id payee_id amount],
    "round_score" => %w[player_id score]
  }.freeze

  def self.valid_context?(frame)
    Play::ModernArt::PLAY_SEQUENCE.include?(frame.state)
  end

  def self.validate!(type, raw_data, state)
    fields = FIELDS[type]
    invalid!("Unknown observation type") unless fields && raw_data.is_a?(Hash)
    invalid!("Unexpected observation fields") unless (raw_data.keys - fields).empty?

    data = fields.index_with do |field|
      next if field == "payee_id" && raw_data[field].blank?

      value = Integer(raw_data[field].to_s, 10, exception: false)
      invalid!("Enter a whole number for #{field.humanize.downcase}") unless value&.between?(0, 2_147_483_647)

      value
    end

    roster_ids = state.fetch("players").reject { |player| player["removed_at"] }.pluck("id")
    (fields & %w[buyer_id payer_id payee_id player_id]).each do |field|
      invalid!("Choose a player from this session") if data[field] && !roster_ids.include?(data[field])
    end
    if type == "auction_result" && !state.fetch("cards").any? { |card| card["id"] == data["card_id"] && card["played_at"] }
      invalid!("Choose a painting already played at the selected point")
    end
    data
  end

  def self.invalid!(message)
    raise SessionFrame::Record::InvalidAction, message
  end
end
