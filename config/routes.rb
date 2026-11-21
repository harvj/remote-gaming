Rails.application.routes.draw do
  get "/up", to: "rails/health#show"
  get "/ready", to: "directory#ready"

  login_host = ->(request) do
    next true unless Rails.env.production?
    next ModernArtStaging::HOSTS.include?(request.host) if ModernArtStaging.enabled?

    GameDirectory::DIRECTORY_HOSTS.include?(request.host) || GameDirectory.new.internal_game(request.host).present?
  end
  constraints login_host do
    get "login", to: "auth#start", as: :login
    get "shell/applications", to: "shell_applications#show", as: :shell_applications
  end

  private_staging = Rails.env.production? && ModernArtStaging.enabled?

  if HistoricalUserAdministration.enabled? || Rails.env.test?
    constraints ->(request) { HistoricalUserAdministration.available_on?(request.host) } do
      get "admin/auth", to: "auth#start_admin", as: :historical_admin_auth
      delete "admin/logout", to: "auth#end_session", as: :historical_admin_logout
      resources :historical_users, path: "admin/historical-users", only: %i[index show update] do
        post :prepare, on: :member
      end
    end
  end

  if Rails.env.production? && !private_staging
    root "directory#show"
    if ProductionReplay.enabled?
      constraints host: ProductionReplay::HOST do
        get "replay", to: "session_replays#index", as: :replays
        get "replay/auth", to: "auth#start", defaults: { return_to: "/replay" }
        delete "replay/logout", to: "auth#end_session", as: :logout
        get "s/:uid/replay", to: "session_replays#show", as: :session_replay
      end
    end
    if CanonicalAuth.enabled? || ProductionReplay.enabled? || HistoricalUserAdministration.enabled?
      constraints host: ProductionReplay::HOST do
        get "auth/callback", to: "auth#callback", as: :auth_callback
        delete "logout", to: "auth#end_session", as: :canonical_logout
      end
    end
    next
  end

  if private_staging
    root "directory#staging", constraints: ->(request) { ModernArtStaging::HOSTS.include?(request.host) }, as: :root
  else
    constraints ->(request) {
      GameDirectory::DIRECTORY_HOSTS.include?(request.host) ||
        request.host.end_with?(".#{GameDirectory::DOMAIN}")
    } do
      root "directory#show", as: :directory_root
    end

    constraints ->(req) { req.subdomain.present? } do
      root "games#show", as: :game_root
    end

    get "/", to: "games#index", constraints: ->(request) { request.format.json? }
    root "directory#show"
  end

  gameplay_host = ->(request) { !private_staging || request.host == ModernArtStaging::GAME_HOST }
  constraints gameplay_host do
    if private_staging
      get "staging/directory", to: "directory#staging_content", defaults: { staging_page: "directory" }
      get "staging/pandemic", to: "directory#staging_content", defaults: { staging_page: "pandemic" }
      get "signed-out", to: "auth#signed_out", as: :staging_signed_out
    end

    resources :game_sessions, only: %i[create]

    resources :players, only: %i[create update] do
      member do
        patch :play
      end
    end

    resources :session_cards, only: %i[update] do
    end

    resources :users, only: %i[show] do
      resource :user_config, only: %i[update], as: :config, path: :config
    end

    devise_for :users,
      skip: (private_staging ? :sessions : []),
      controllers: { sessions: "users/sessions" },
      path: "",
      path_names: {
        sign_in: "login",
        sign_out: "logout"
      }

    get "dummy/login", to: "dummy_accesses#new", as: :dummy_login
    post "dummy/login", to: "dummy_accesses#redeem"
    delete "dummy/logout", to: "dummy_accesses#logout", as: :dummy_logout
    post "s/:uid/dummies", to: "dummy_accesses#create", as: :session_dummies
    post "s/:uid/dummies/:player_id/rotate", to: "dummy_accesses#rotate", as: :rotate_session_dummy
    delete "s/:uid/dummies/:player_id", to: "dummy_accesses#revoke", as: :session_dummy

    match "auth/start", to: "auth#start", as: :auth_start, via: %i[get post]
    get "auth/callback", to: "auth#callback", as: :auth_callback

    if private_staging
      delete "/logout", to: "auth#end_session", as: :logout
    else
      devise_scope :user do
        delete "/logout", to: "users/sessions#destroy", as: :logout
      end
    end

    get "s/:uid/replay", to: "session_replays#show", as: :session_replay
    post "s/:uid/branches", to: "session_branches#create", as: :session_branches,
      constraints: ->(_request) { ExperimentalAccess.enabled? }
    get "s/:uid" => "game_sessions#show", as: :game_session
    patch "s/:uid" => "game_sessions#update"
    post "s/:uid/observations" => "game_sessions#observe", as: :session_observations

    game_constraints = private_staging ? { game_key: ModernArtStaging::GAME_KEY } : {}
    get ":game_key" => "games#show", as: :game, constraints: game_constraints
  end
end
