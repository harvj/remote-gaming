class SessionCard::Build < Services::Build
  def build_child
    parent.cards.build(params)
  end
end
