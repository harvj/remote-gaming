module Query
  class Players < Query::Base
    def score_stats
      Player.find_by_sql(
        <<~SQL,
          SELECT
            avg(players.score)::INTEGER,
            stddev(players.score)::INTEGER,
            count(distinct players.game_session_id) as game_count,
            (SELECT count(*) FROM players p WHERE p.game_session_id = players.game_session_id) as player_count
          FROM players
          JOIN game_sessions ON game_sessions.id = game_session_id
          WHERE game_sessions.game_id = ?
          AND players.score IS NOT NULL
          GROUP BY player_count
        SQL
        params[:game_id]
      )
    end

    def user_stats
      Player.find_by_sql(
        <<~SQL,
          SELECT * FROM ( SELECT
            username,
            player_count,
            array_agg(score),
            avg(score)::integer AS average,
            max(score) AS high_score,
            min(score) AS low_score,
            count(CASE WHEN x.winner THEN 1 END) AS wins,
            count(x) AS games_played,
            max(cards_table.cards_per) as doubles_per
          FROM (
            SELECT
              users.username,
              players.score,
              players.winner,
              (SELECT count(*) FROM players WHERE players.game_session_id = game_sessions.id) AS player_count
            FROM players
            JOIN users ON players.user_id = users.id
            JOIN game_sessions ON players.game_session_id = game_sessions.id
            WHERE players.score IS NOT NULL
            AND game_sessions.game_id = :game_id
          ) AS x
          JOIN (
            SELECT users.username as cards_username,
              round(count(session_cards.id)::decimal / count(distinct session_cards.game_session_id), 2) AS cards_per,
              (SELECT count(*) FROM players WHERE players.game_session_id = game_sessions.id) AS cards_player_count
            FROM session_cards
            JOIN game_sessions on session_cards.game_session_id = game_sessions.id
            JOIN cards on cards.id = session_cards.card_id
            JOIN players on session_cards.player_id = players.id and players.score IS NOT NULL
            JOIN users on players.user_id = users.id
            WHERE game_sessions.game_id = :game_id
            AND cards.value = 'double'
            GROUP BY cards_username, cards_player_count
          ) AS cards_table ON cards_table.cards_username = x.username AND cards_table.cards_player_count = x.player_count
          GROUP BY x.username, player_count
          ORDER BY player_count DESC, average DESC
        ) AS y WHERE y.games_played > 1
        SQL
        { game_id: params[:game_id] }
      )
    end

    def single_double_stats
      User.find_by_sql(<<~SQL
        WITH single_doubles AS ( SELECT session_frames.id,
          players.id as pid,
          users.id as uid,
          users.username,
          single_double.name,
          single_double.value,
          affected_user.id as auid,
          affected_user.username as affected_user,
          single_double.action,
          game_sessions.completed_at,
          session_frames.created_at,
          session_frames.state,
          game_sessions.id as gsid
        FROM session_frames
        join game_sessions on game_sessions.id = session_frames.game_session_id
        join players on session_frames.acting_player_id = players.id
        join users on players.user_id = users.id
        join players as affected on players.next_player_id = affected.id
        join users as affected_user on affected.user_id = affected_user.id
        join ( select session_frames.id,
            session_frames.action,
            cards.name,
            cards.value
          from session_frames
          left outer join session_cards on session_cards.id = session_frames.subject_id and subject_type = 'SessionCard'
          left outer join cards on session_cards.card_id = cards.id
          where session_frames.action = 'card_played'
        ) as single_double on session_frames.previous_frame_id = single_double.id
        where game_sessions.game_id = 1
        and session_frames.action = 'player_pass' )

        select id, username, sd_played_on_count, sd_played_count, games,
          round(sd_played_on_count::decimal / NULLIF(games, 0), 2) as sd_played_on_avg,
          round(sd_played_count::decimal / NULLIF(games, 0), 2) as sd_played_avg,
          round(round(sd_played_count::decimal / NULLIF(games, 0), 2) / round(sd_played_on_count::decimal / NULLIF(games, 0), 2), 2) as sd_ratio
        FROM (
          select users.id, users.username, a.sd_played_on_count, b.sd_played_count,
          (select count(*) from players where players.game_session_id >= 60 and players.user_id = users.id and players.game_id = 1) as games
          from users
          join (
            select users.id, count(single_doubles.auid) as sd_played_on_count from users
            left outer join single_doubles on single_doubles.auid = users.id
            group by users.id) as a on users.id = a.id
          join (
            select users.id, count(single_doubles.uid) as sd_played_count from users
            left outer join single_doubles on single_doubles.uid = users.id
            group by users.id) as b on users.id = b.id
        ) as sd_data where games > 3
      SQL
      )
    end

    def turn_order_stats
      Player.find_by_sql(<<~SQL
        SELECT * FROM ( SELECT
          turn_order,
          player_count,
          array_agg(score),
          avg(score)::integer AS average,
          max(score) AS high_score,
          min(score) AS low_score,
          count(CASE WHEN x.winner THEN 1 END) AS wins,
          count(x) AS games_played
        FROM (
          SELECT
            users.username,
            players.turn_order,
            players.score,
            players.winner,
            (SELECT count(*) FROM players WHERE players.game_session_id = game_sessions.id) AS player_count
          FROM players
          JOIN users ON players.user_id = users.id
          JOIN game_sessions ON players.game_session_id = game_sessions.id
          WHERE players.score IS NOT NULL
          AND game_sessions.game_id = 1
        ) AS x
        GROUP BY x.turn_order, player_count
        ORDER BY player_count DESC, turn_order ASC
      ) AS y
      SQL
      )
    end

    def non_winners_from_date
      Player.find_by_sql(
        <<~SQL,
          SELECT
            users.username,
            players.score,
            (SELECT count(*) FROM players WHERE players.game_session_id = game_sessions.id) AS player_count
          FROM game_sessions
          JOIN players ON players.game_session_id = game_sessions.id
          JOIN users ON players.user_id = users.id
          WHERE timezone('US/Pacific', completed_at AT TIME ZONE 'utc')::DATE = :date
          AND users.id NOT IN
            ( SELECT DISTINCT user_id FROM game_sessions
              JOIN players ON players.game_session_id = game_sessions.id
              WHERE timezone('US/Pacific', completed_at AT TIME ZONE 'utc')::DATE = :date
              AND winner IS TRUE
            )
          AND players.game_id = :game_id
        SQL
        {
          date: params[:date].strftime("%Y-%m-%d"),
          game_id: params[:game_id]
        }
      )
    end

    def modern_art_card_stats
      Player.find_by_sql(<<~SQL
        SELECT * FROM ( SELECT
          users.username,
          count(distinct players.id) as games_played,
          count(session_frames.id) as cards_played,
          (count(CASE WHEN cards.name = 'lite_metal' THEN 1 END)::decimal / count(distinct players.id)) as lite_metal_crown,
          (count(CASE WHEN cards.name = 'yoko' THEN 1 END)::decimal / count(distinct players.id)) as yoko_crown,
          (count(CASE WHEN cards.name = 'cristin_p' THEN 1 END)::decimal / count(distinct players.id)) as cristin_p_crown,
          (count(CASE WHEN cards.name = 'karl_gitter' THEN 1 END)::decimal / count(distinct players.id)) as gitter_crown,
          (count(CASE WHEN cards.name = 'krypto' THEN 1 END)::decimal / count(distinct players.id)) as krypto_crown,
          (count(CASE WHEN cards.value = 'fixed' THEN 1 END)::decimal / count(distinct players.id)) as fixed_crown,
          (count(CASE WHEN cards.value = 'double' THEN 1 END)::decimal / count(distinct players.id)) as double_crown,
          (count(CASE WHEN cards.value = 'open' THEN 1 END)::decimal / count(distinct players.id)) as open_crown,
          (count(CASE WHEN cards.value = 'sealed' THEN 1 END)::decimal / count(distinct players.id)) as sealed_crown,
          (count(CASE WHEN cards.value = 'once_around' THEN 1 END)::decimal / count(distinct players.id)) as once_around_crown
        FROM players
        JOIN users ON users.id = players.user_id
        JOIN session_frames ON players.game_session_id = session_frames.game_session_id AND session_frames.action = 'card_played'
        JOIN game_sessions ON players.game_session_id = game_sessions.id
        JOIN games ON game_sessions.game_id = games.id
        JOIN session_cards ON session_frames.subject_id = session_cards.id AND session_frames.acting_player_id = players.id
        JOIN cards ON cards.id = session_cards.card_id
        WHERE games.id = 1
        AND game_sessions.completed_at > '2021-01-02'
        GROUP BY users.id ) AS x
        WHERE x.games_played > 5
      SQL
      )
    end

    def current_win_streak
      Player.find_by_sql(<<~SQL
        select count(*) as streak from players
        join ( select x.user_id, players.id
          from ( select user_id from players where winner is true and game_id = 1 order by id desc limit 1 ) as x
          join players on players.user_id <> x.user_id and winner is true order by id desc limit 1 )
         as y on y.user_id = players.user_id
         where winner is TRUE
         and players.id > y.id
      SQL
      ).first
    end
  end
end
