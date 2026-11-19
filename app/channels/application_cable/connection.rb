module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      if ModernArtStaging.enabled? && request.host != ModernArtStaging::GAME_HOST
        reject_unauthorized_connection
      end

      self.current_user = find_verified_user
    end

    def allowed_at_table?(table)
      if request.session.key?(:dummy_browser)
        grant = DummyAccess.authorized(request.session[:dummy_browser])
        grant && grant.player.game_session_id == table.id && table.can_view?(grant.user)
      else
        table.can_view?(BrowserIdentity.oidc_user(request.session))
      end
    end

    private

    def find_verified_user
      user = if CanonicalAuth.enabled?
        if request.session.key?(:dummy_browser)
          DummyAccess.authorized(request.session[:dummy_browser])&.user
        else
          BrowserIdentity.oidc_user(request.session)
        end
      else
        env["warden"]&.user
      end
      if user
        user
      else
        reject_unauthorized_connection
      end
    end
  end
end
