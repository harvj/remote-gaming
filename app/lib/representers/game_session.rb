module Representers
  class GameSession < Representers::Base
    attr_reader :session

    def build_object(session)
      @session = session
      member = viewer && session.players.find_by(user: viewer)
      replayable = session.replayable?
      scalar = {
        active: session.active?,
        allowDisplayPlayerSwitching: session.allow_display_player_switching?,
        archived: session.completed_at.present? && session.completed_at < 2.months.ago,
        completed: session.completed_at.present?,
        completedAt: session.completed_at&.strftime("%a %e %b %Y %k:%M:%S"),
        completedAtDate: session.completed_at&.strftime("%e %b %Y"),
        createdAt: session.created_at.to_i,
        joinable: replayable && !member && session.joinable?,
        nextActionPrompt: session.next_action_prompt,
        playable: replayable && session.playable?,
        readOnly: !replayable,
        revision: session.frames.maximum(:sequence) || 0,
        canStart: replayable && member&.table_captain? && session.waiting? && session.playable?,
        playerCount: session.players.count,
        promptForPlayerScore: replayable && session.prompt_for_player_score?,
        showInactiveCards: session.show_inactive_cards?,
        specialGamePhase: session.special_game_phase,
        started: session.started_at.present?,
        startedAt: session.started_at&.strftime("%a %e %b %Y %k:%M:%S"),
        startedAtDate: session.started_at&.strftime("%e %b %Y"),
        state: session.display_state,
        terms: session.play_class::TERMS,
        uid: session.uid,
        uri: game_session_path(session.uid),
        waiting: session.waiting?
      }
      return scalar if scalar_only?

      scalar.merge!(
        displayCardGroups: session.display_card_groups.map do |group|
          {
            name: group[:name],
            count: group[:count],
            cards: Representers::SessionCard.(group[:cards])
          }
        end,
        game: Representers::Game.(session.game, scalar: true),
        players: Representers::Player.(players, viewer: viewer, reveal: member && session.completed? && session.game.key == "modern_art")
      )

      scalar.merge!(currentPlayerId: session.current_player.id, currentPlayerName: session.current_player.user.name) if session.current_player.present?

      if member && replayable && session.game.key == "modern_art"
        scalar[:physical] = physical_history(member)
      elsif member && !replayable
        scalar[:physical] = { coverage: "unrecorded", observations: [] }
      end

      scalar
    end

    def physical_history(member)
      history = ::SessionFrame::Tabletop.call(session.frames.observations.order(:sequence))
      history[:observations] = history.fetch(:observations).map do |frame|
        { id: frame.id, type: frame.action, phase: frame.state, provenance: frame.kind, actorId: frame.acting_player_id,
          recordedAt: frame.created_at.iso8601, occurredAt: frame.occurred_at&.iso8601, contextId: frame.context_frame_id,
          correctsId: frame.corrects_frame_id, data: frame.payload,
          cardLabel: observation_card_label(frame) }
      end
      return history unless member.table_captain?

      history.merge(
        path: session_observations_path(session.uid),
        contexts: session.frames.checkpoints.where(state: Play::ModernArt::PLAY_SEQUENCE).order(:sequence).map do |frame|
          state = frame.payload
          { id: frame.id, label: "#{frame.state.titleize} · #{frame.sequence}",
            cards: state.fetch("cards").filter_map do |card|
              next unless card["played_at"]

              definition = card.fetch("definition")
              { id: card["id"], label: "#{definition.fetch('name').titleize} · #{definition.fetch('value').titleize}" }
            end }
        end
      )
    end

    def observation_card_label(frame)
      return unless frame.action == "auction_result"

      card = frame.context_frame.payload.fetch("cards").find { |item| item["id"] == frame.payload["card_id"] }
      definition = card.fetch("definition")
      "#{definition.fetch('name').titleize} · #{definition.fetch('value').titleize}"
    end

    def players
      ::Player.find_by_sql(<<~SQL
        SELECT players.*,
          min(last_win.date) as last_win_date,
          coalesce(json_agg(json_build_object(
            'value', (CASE WHEN badges.display_int THEN round(user_badges.value,0)::varchar ELSE user_badges.value::varchar END),
            'color', badges.color,
            'icon_class', badges.icon_class,
            'symbol', badges.symbol,
            'hideable', badges.hideable
            ) ORDER BY badges.sort_order
            ) FILTER (WHERE user_badges.id IS NOT NULL), '[]'
          ) AS badges
        FROM players
        JOIN users ON users.id = players.user_id
        LEFT OUTER JOIN ( select users.id, date(game_sessions.started_at at time zone 'utc' at time zone 'america/los_angeles')
            from users
            join players on players.id = (
              select players.id from players
              join game_sessions on game_sessions.id = players.game_session_id
              where players.user_id = users.id
              and winner is true
              and game_sessions.game_id = #{session.game_id}
              order by players.created_at desc limit 1
            )
            join game_sessions on game_sessions.id = players.game_session_id
            order by game_sessions.started_at desc
          ) as last_win on last_win.id = users.id
        LEFT OUTER JOIN badges ON badges.game_id = #{session.game_id}
        LEFT OUTER JOIN user_badges ON users.id = user_badges.user_id AND badges.id = user_badges.badge_id AND user_badges.active = TRUE
        WHERE game_session_id = #{session.id}
        AND removed_at IS NULL
        GROUP BY players.id
        ORDER BY players.turn_order
      SQL
      )
    end
  end
end
