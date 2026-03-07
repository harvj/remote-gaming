class SessionFrame::Create < Services::Create
  def initialize(session, params={})
    super(session,
      params.merge(
        previous_frame: session.frames.last,
        state: session.state
      )
    )
  end
end
