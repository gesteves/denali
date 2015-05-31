Rails.application.routes.draw do
  concern :paginatable do
    get '(page/:page)', :action => :index, :on => :collection, :as => ''
  end

  namespace :admin do
    get 'settings' => 'blogs#edit'
    patch 'settings/update' => 'blogs#update'

    resources :entries, only: [:index, :new, :create, :edit, :update, :destroy], :concerns => :paginatable do
      member do
        get 'preview'
        patch 'publish'
        patch 'queue'
        patch 'draft'
        post 'reposition'
      end
      collection do
        get 'queued'
        get 'drafts'
        get 'photo'
      end
    end
  end


  get '/page/:page'               => 'entries#index',  constraints: { page: /\d+/ }
  get '/tagged/:tag(/page/:page)' => 'entries#tagged', constraints: { page: /\d+/ }, :as => :tag
  get '/:id(/:slug)'              => 'entries#show',   constraints: { id: /\d+/ }, :as => :entry
  get '/post/:tumblr_id(/:slug)'  => 'entries#tumblr', constraints: { tumblr_id: /\d+/ }
  get '/rss'                      => 'entries#rss', defaults: { format: 'atom' }

  get '/admin'                    => 'admin#index'
  get '/auth/:provider/callback'  => 'sessions#create'
  get '/auth/failure'             => 'sessions#failure'
  get '/signin'                   => 'sessions#new',     :as => :signin
  get '/signout'                  => 'sessions#destroy', :as => :signout

  root 'entries#index'
end
