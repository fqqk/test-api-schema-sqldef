Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users, only: [:index, :show, :create, :update, :destroy] do
        resources :posts, only: [:index, :show, :create, :update, :destroy]
      end
      
      resources :posts, only: [:index, :show, :create, :update, :destroy] do
        resources :comments, only: [:index, :create]
        member do
          patch :publish
          patch :unpublish
        end
      end
      
      resources :categories, only: [:index, :show, :create, :update, :destroy]
      resources :comments, only: [:index, :show, :create, :update, :destroy]
    end
  end
  
  # Health check endpoint (already exists in Rails 8)
  get "up" => "rails/health#show", as: :rails_health_check
end
