module Representers
  class User < Representers::Base
    def build_object(user)
      {
        name: user.name,
        uri: user_path(user),
        username: user.username,
        configPath: user_config_path(user),
        config: {
          showAllBadges: user.config.show_all_badges?,
          showBadgeValues: user.config.show_badge_values?
        }
      }
    end
  end
end
