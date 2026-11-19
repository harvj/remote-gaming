class SessionFrame::Create < Services::Create
  def initialize(session, params = {})
    last = session.frames.reorder(:sequence).last
    subject = params[:subject]
    if subject.is_a?(SessionCard) && !params.key?(:payload)
      params = params.merge(payload: { card: subject.card.slice(*SessionFrame::Snapshot::CATALOG_FIELDS) })
    end
    actor = params[:acting_player]
    params[:actor_kind] = actor.user.dummy? ? "dummy" : "person" if actor
    super(session, {
      previous_frame: last, state: session.state, kind: "engine",
      sequence: (last&.sequence || 0) + 1, game_key: session.game.key, format_version: 1
    }.merge(params))
  end
end
