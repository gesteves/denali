Rails.application.routes.draw do

  concern :paginatable do
    get '(page/:page)', :action => :index, :on => :collection, :as => ''
  end

  namespace :admin do
    get '/tagged/:tag(/page/:page)'   => 'entries#tagged', constraints: { page: /\d+/ }, :as => 'tagged_entries'
    get '/entries/edit'               => 'entries#edit'
    get '/entries/share'              => 'entries#share'
    get 'settings'                    => 'blogs#edit'
    patch 'settings/update'           => 'blogs#update'

    resources :entries, only: [:index, :new, :create, :edit, :update, :destroy], concerns: :paginatable do
      member do
        get 'delete'
        get 'share'
        patch 'publish'
        patch 'queue'
        patch 'draft'
        post 'up'
        post 'down'
        post 'top'
        post 'bottom'
        post 'instagram'
        post 'twitter'
        post 'facebook'
      end
      collection do
        get 'queued'
        get 'drafts'
        get 'photo'
      end
    end

    resources :tags, only: [:index, :destroy], concerns: :paginatable
  end


  get '/(page/:page)'                  => 'entries#index',   constraints: { page: /\d+/ }, defaults: { format: 'html' }, :as => :entries
  get '/count/:count'                  => 'entries#index',   constraints: { count: /\d+/ }, defaults: { format: 'html' }
  get '/tagged/:tag(/page/:page)'      => 'entries#tagged',  constraints: { page: /\d+/ }, defaults: { format: 'html' }, :as => :tag
  get '/tagged/:tag(/count/:count)'    => 'entries#tagged',  constraints: { count: /\d+/ }, defaults: { format: 'html' }
  get '/e/:id'                         => 'entries#show',    constraints: { id: /\d+/ }, :as => :entry
  get '/:year/:month/:day/:id(/:slug)' => 'entries#show',    constraints: { id: /\d+/, year: /\d{1,4}/, month: /\d{1,2}/, day: /\d{1,2}/ }, defaults: { format: 'html' }, :as => :entry_long
  get '/preview/:preview_hash'         => 'entries#preview', defaults: { format: 'html' }, :as => :preview_entry
  get '/map'                           => 'maps#index', :as => :map
  get '/map/photos.:format'            => 'maps#photos'
  get '/map/photo/:id.:format'         => 'maps#photo'
  get '/sitemap.:format'               => 'entries#sitemap', defaults: { format: 'xml' }, :as => :sitemap
  get '/about'                         => 'blogs#about', :as => :about
  get '/offline'                       => 'blogs#offline',  :as => :offline
  get '/manifest.json'                 => 'blogs#manifest', :as => :app_manifest
  get '/oembed'                        => 'oembed#show', :as => :oembed

  # Redirects
  get '/post/:tumblr_id(/:slug)'       => 'entries#tumblr', constraints: { tumblr_id: /\d+/ }

  # Feeds
  get '/feed'                          => 'entries#index', defaults: { format: 'atom' }, :as => :simple_feed
  get '/rss'                           => 'entries#index', defaults: { format: 'atom' }
  get '/atom'                          => 'entries#index', defaults: { format: 'atom' }

  # Admin
  get '/admin'                         => 'admin#index',      :as => :admin
  get '/auth/:provider/callback'       => 'sessions#create'
  get '/auth/failure'                  => 'sessions#failure'
  get '/signin'                        => 'sessions#new',     :as => :signin
  get '/signout'                       => 'sessions#destroy', :as => :signout

  # PWA
  get '/service_worker.js'             => 'service_worker#index', defaults: { format: 'js' }

  # The rest
  get 'robots.:format'                 => 'robots#show', defaults: { format: 'txt' }
  root 'entries#index'
  match '/404', to: 'errors#file_not_found', via: :all
  match '/422', to: 'errors#unprocessable', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
