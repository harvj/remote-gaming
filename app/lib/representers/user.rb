module Representers
  class User < Representers::Base
    def build_object(user)
      config = user.config
      {
        name: user.name,
        uri: user.dummy? ? nil : user_path(user),
        username: user.username,
        configPath: user.dummy? ? nil : user_config_path(user),
        config: {
          showAllBadges: config ? config.show_all_badges? : true,
          showBadgeValues: config ? config.show_badge_values? : true
        }
      }
    end
  end
end
