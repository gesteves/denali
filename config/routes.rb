Rails.application.routes.draw do
  namespace :admin do
    get 'settings' => 'blogs#edit'
    patch 'settings/update' => 'blogs#update'

    resources :entries, only: [:index, :new, :create, :edit, :update, :destroy] do
      member do
        get 'preview'
        patch 'publish'
        patch 'queue'
        patch 'draft'
      end
      collection do
        get 'queued'
        get 'drafts'
        get 'photo'
      end
    end
  end

  get '/admin'                   => 'admin#index'
  get '/auth/:provider/callback' => 'sessions#create'
  get '/auth/failure'            => 'sessions#failure'
  get '/signin'                  => 'sessions#new',     :as => :signin
  get '/signout'                 => 'sessions#destroy', :as => :signout

  root 'admin#index'
end
