class SessionFrame::Tabletop
  def self.call(frames, through: nil)
    reports = frames.filter_map do |frame|
      next unless %w[observation correction].include?(frame.kind)
      next if through && frame.sequence > through

      if frame.format_version != 1
        raise SessionFrame::Replay::Unavailable, "Unsupported observation format"
      end
      frame
    end
    superseded = reports.filter_map(&:corrects_frame_id).to_set
    {
      coverage: "incomplete",
      observations: reports.reject { |frame| superseded.include?(frame.id) }.sort_by do |frame|
        [ frame.context_frame_id, (frame.occurred_at || frame.created_at).to_f, frame.sequence ]
      end
    }
  end
end
