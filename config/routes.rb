Rails.application.routes.draw do
  namespace :admin do
    get 'settings' => 'blogs#edit'
    patch 'settings/update' => 'blogs#update'

    resources :entries, only: [:index, :new, :create, :edit, :update, :destroy] do
      member do
        get 'preview'
      end
      collection do
        get 'queued'
        get 'drafts'
      end
    end
  end

  get '/auth/:provider/callback' => 'sessions#create'
  get '/auth/failure'            => 'sessions#failure'
  get '/signin'                  => 'sessions#new',     :as => :signin
  get '/signout'                 => 'sessions#destroy', :as => :signout
end
