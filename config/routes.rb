# frozen_string_literal: true

Rails.application.routes.draw do
  # Liveness/readiness probe. Returns 200 when the app has booted and can reach
  # the database; used by the container HEALTHCHECK.
  get 'up' => 'rails/health#show', as: :rails_health_check

  devise_for :users,
             path: '',
             path_names: { sign_in: 'login', sign_out: 'logout', registration: 'signup' },
             controllers: { sessions: 'users/sessions', registrations: 'users/registrations' }

  namespace :api do
    namespace :v1 do
      resources :events do
        collection do
          post 'add_user_to_events'
          get 'get_events'
          get 'joined_events'
        end
      end
    end
  end
end
