module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      if ModernArtStaging.enabled? && request.host != ModernArtStaging::GAME_HOST
        reject_unauthorized_connection
      end

      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      if (user = env["warden"]&.user) # Devise
        user
      else
        reject_unauthorized_connection
      end
    end
  end
end
