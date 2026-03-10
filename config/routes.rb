Rails.application.routes.draw do
  constraints ->(req) { req.subdomain.present? } do
    root "games#show", as: :game_root
  end

  root "games#index"

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
    controllers: { sessions: "users/sessions" },
    path: "",
    path_names: {
      sign_in: "login",
      sign_out: "logout"
    }

  devise_scope :user do
    get "/login", to: "users/sessions#new", as: :login
    delete "/logout", to: "users/sessions#destroy", as: :logout
  end

  get "s/:uid" => "game_sessions#show", as: :game_session
  patch "s/:uid" => "game_sessions#update"
  delete "s/:uid" => "game_sessions#destroy"

  get ":game_key" => "games#show", as: :game
end
