Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "api/health" => "rails/health#show"

  resource :session, only: %i[ new create destroy ]
  resource :registration, only: %i[ new create ]
  resources :users, only: :show, param: :username
  resource :settings, only: %i[ show update ]
  namespace :settings do
    resource :password, only: :update
    resource :account, only: :destroy
  end
  resources :activities, only: :index

  root "pages#home"
end
