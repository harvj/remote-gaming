class GameSession::Build < Services::Build
  def build_child
    parent.sessions.build(params)
  end
end
