class SessionFrame::Build < Services::Build
  def build_child
    parent.frames.build(params)
  end
end
