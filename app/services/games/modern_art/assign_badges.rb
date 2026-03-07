module Games
  class ModernArt::AssignBadges
    include ServiceObject

    def initialize
      @game = Game.find_by(key: 'modern_art')
      @last_session = game.sessions.completed.last
    end

    def call
      Game.transaction do
        assign_dog_man
        assign_card_badges
        assign_win_streak
      end
    end

    attr_reader :game, :last_session

    def assign_dog_man
      badge = game.badges.find_by(name: 'dog_man')
      return if already_assigned?(badge)

      results = {}
      players = Query::Players.(:non_winners_from_date, game_id: game.id, date: last_session.completed_at).group_by(&:username)
      stats   = Query::Players.(:score_stats, game_id: game.id).group_by(&:player_count)

      players.each do |username, sessions|
        stddevs = sessions.map do |session|
          diff = session.score - stats[session.player_count].first.avg
          diff.to_f / stats[session.player_count].first.stddev
        end
        results[username] = stddevs.sum / stddevs.length
      end

      dog_user, dog_score = results.min_by {|name, score| score}

      create_user_badge(badge, dog_user, dog_score.round(2).to_f)
    end

    def assign_card_badges
      %i(lite_metal yoko cristin_p gitter krypto fixed double open sealed once_around).each do |card_type|
        %i(up down).each do |direction|
          badge = game.badges.find_by(name: "#{card_type}_#{direction}")
          next if badge.nil?
          next if already_assigned?(badge)

          which_one = direction == :up ? 'last' : 'first'
          stats = Query::Players.(:modern_art_card_stats)
          recipient = stats.sort_by{|p| p.send("#{card_type}_crown")}.send(which_one)

          create_user_badge(badge, recipient.username, recipient.send("#{card_type}_crown").round(1).to_f)
        end
      end

      %i(sd_ratio_first sd_ratio_last).each do |badge_name|
        badge = game.badges.find_by(name: badge_name)
        next if badge.nil?
        next if already_assigned?(badge)

        which_one = badge_name.to_s.split('_').last
        stats = Query::Players.(:single_double_stats)
        recipient = stats.sort_by{ |row| -row.sd_ratio }.send(which_one)
        create_user_badge(badge, recipient.username, recipient.sd_ratio)
      end
    end

    def assign_win_streak
      badge = game.badges.find_by(name: 'win_streak')
      return if already_assigned?(badge)
      create_user_badge(badge, last_session.winner.user.username, Query::Players.(:current_win_streak).streak)
    end

    # --- Util

    def already_assigned?(badge)
      active = badge.user_badges.active
      if active.present? && active.as_of_session == last_session
        log("Already an active #{badge.name} badge as of session #{last_session.id}")
        true
      else
        deactivate(badge, active) if active.present?
        false
      end
    end

    def deactivate(badge, active)
      log("Deactivating #{badge.name} badge #{active.id}")
      active.update(active: false)
    end

    def create_user_badge(badge, username, value)
      log("Creating #{badge.name} badge for #{username}: #{value}")
      UserBadge.create(
        badge: badge,
        user: User.find_by(username: username),
        value: value,
        as_of_session: last_session
      )
    end

  end
end
