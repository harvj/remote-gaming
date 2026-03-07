module Representers
  class GameSession < Representers::Base
    attr_reader :session

    def build_object(session)
      @session = session
      scalar = {
        active: session.active?,
        allowDisplayPlayerSwitching: session.allow_display_player_switching?,
        archived: session.completed_at.present? && session.completed_at < 2.months.ago,
        completed: session.completed_at.present?,
        completedAt: session.completed_at&.strftime("%a %e %b %Y %k:%M:%S"),
        completedAtDate: session.completed_at&.strftime("%e %b %Y"),
        createdAt: session.created_at.to_i,
        joinable: session.joinable?,
        nextActionPrompt: session.next_action_prompt,
        playable: session.playable?,
        playerCount: session.players.count,
        promptForPlayerScore: session.prompt_for_player_score?,
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
        players: Representers::Player.(players)
      )

      scalar.merge!(currentPlayerId: session.current_player.id, currentPlayerName: session.current_player.user.name) if session.current_player.present?

      logged_in_player = session.players.find_by(user: user)
      scalar.merge!(loggedInPlayer: Representers::Player.(logged_in_player)) if logged_in_player.present?

      scalar
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
        GROUP BY players.id
        ORDER BY players.turn_order
      SQL
      )
    end
  end
end
