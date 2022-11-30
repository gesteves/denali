Rails.application.routes.draw do
  require 'sidekiq/web'
  require 'sidekiq-scheduler/web'
  mount Sidekiq::Web => '/admin/sidekiq', constraints: lambda { |request| request.session[:user_id].present? && User.find(request.session[:user_id]).present? }

  match '/404', to: 'errors#file_not_found', via: :all
  match '/422', to: 'errors#unprocessable', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all

  concern :paginatable do
    get '(page/:page)', :action => :index, :on => :collection
    get 'queued(/page/:page)', :action => :queued, :on => :collection
    get 'drafts(/page/:page)', :action => :drafts, :on => :collection
  end

  namespace :admin do
    get '/entries/tagged/:tag(/page/:page)'     => 'entries#tagged', constraints: { page: /\d+/ }, :as => 'tagged_entries'
    get '/entries/search'             => 'entries#search', :as => :search
    get '/entries/edit'               => 'entries#edit'
    get '/entries/share'              => 'entries#share'
    get '/entries/queued/organize'    => 'entries#organize_queue'
    post '/entries/queued/update'     => 'entries#update_queue'
    get '/entries/queued/schedule'    => 'publish_schedules#index'
    get '/equipment'                  => 'equipment#index'
    get '/locations'                  => 'locations#index'
    get '/map'                        => 'maps#index', :as => :map
    get '/map/photos.:format'         => 'maps#photos', :as => :map_markers
    get '/map/photo/:id.:format'      => 'maps#photo', :as => :map_photo

    resources :entries, concerns: :paginatable do
      member do
        get 'crops'
        get 'prints'
        get 'instagram'
        get 'reblog'
        patch 'publish'
        patch 'queue'
        patch 'draft'
        post 'instagram'
        post 'tumblr'
        post 'tumblr_reblog'
        post 'tumblr_update'
        post 'refresh_metadata'
      end
      collection do
        get 'queued'
        get 'drafts'
        get 'photo'
      end
      resources :photos, only: [] do
        member do
          get 'download'
          post 'focal_point'
          post 'banner'
        end
        resources :crops, only: [] do
          collection do
            post 'create_or_update'
          end
        end
      end
    end

    resources :tags, only: [:index, :destroy, :show, :update], concerns: :paginatable do
      member do
        post 'add'
      end
    end

    resources :blogs, only: [:edit, :update] do
      member do
        post 'flush_caches'
      end
    end

    resources :cameras, only: [:edit, :update]
    resources :lenses, only: [:edit, :update]
    resources :films, only: [:edit, :update]
    resources :parks, only: [:edit, :update]
    resources :profiles, only: [:edit, :update]
    resources :publish_schedules, only: [:create, :destroy]
    resources :tag_customizations, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :webhooks, except: [:show]
  end

  # Entries
  root 'entries#index'
  get '/(page/:page)'                   => 'entries#index',   constraints: { page: /\d+/ }, defaults: { format: 'html' }, :as => :entries
  get '/tagged/:tag(/page/:page)'       => 'entries#tagged',  constraints: { page: /\d+/ }, defaults: { format: 'html' }, :as => :tag
  get '/search'                         => 'entries#search', :as => :search
  get '/random'                         => 'entries#random', :as => :random
  get '/profile/:username(/page/:page)' => 'entries#profile', constraints: { page: /\d+/ }, defaults: { format: 'html' }, :as => :profile

  # Entry
  get '/p/:id'                              => 'entries#short',       constraints: { id: /\w+/ }, :as => :entry
  get '/preview/:preview_hash(/:slug)'      => 'entries#show',        defaults: { format: 'html' }, :as => :preview_entry
  get '/:id(/:slug)'                        => 'entries#show',        constraints: { id: /\d+/ }, defaults: { format: 'html' }, :as => :entry_long
  get '/related/:id.:format'                => 'entries#related',     defaults: { format: 'js' }, constraints: { id: /\d+/ }, :as => :related
  get '/related/:preview_hash.:format'      => 'entries#related',     defaults: { format: 'js' }, :as => :related_preview

  # Feeds
  get '/feed(.:format)'                  => 'entries#feed', defaults: { format: 'atom' }, :as => :feed
  get '/tagged/:tag/feed(.:format)'      => 'entries#tag_feed', defaults: { format: 'atom' }, :as => :tag_feed
  get '/author/:username/feed(.:format)' => 'entries#profile_feed', defaults: { format: 'atom' }, :as => :profile_feed

  # Sitemaps
  get '/sitemap.:format'               => 'sitemaps#index', defaults: { format: 'xml' }, :as => :sitemap
  get '/sitemap/entries/:page.:format' => 'sitemaps#entries', constraints: { page: /\d+/ }, defaults: { format: 'xml' }, :as => :entries_sitemap
  get '/sitemap/tags/:page.:format'    => 'sitemaps#tags', constraints: { page: /\d+/ }, defaults: { format: 'xml' }, :as => :tags_sitemap

  # GraphQL
  match '/graphql'                     => 'graphql#options', via: :options
  post '/graphql'                      => 'graphql#execute'

  #PWA
  get '/service_worker.js'             => 'service_worker#index', defaults: { format: 'js' }, :as => :service_worker

  # Admin
  get '/admin'                         => 'admin#index',      :as => :admin
  get '/auth/:provider/callback'       => 'sessions#create'
  get '/auth/failure'                  => 'sessions#failure'
  get '/signin'                        => 'sessions#new',     :as => :signin
  get '/signout'                       => 'sessions#destroy', :as => :signout

  # Legacy routes & redirects
  get '/archive(/:year)(/:month)'           => 'legacy#home'
  get '/index.html'                         => 'legacy#home'
  get '/rss'                                => 'legacy#feed'
  get '/:year/:month/:day/:id(/:slug)'      => 'entries#show',   constraints: { id: /\d+/, year: /\d{1,4}/, month: /\d{1,2}/, day: /\d{1,2}/ }, defaults: { format: 'html' }
  get '/amp/:year/:month/:day/:id(/:slug)'  => 'entries#amp',    constraints: { id: /\d+/, year: /\d{1,4}/, month: /\d{1,2}/, day: /\d{1,2}/ }, defaults: { format: 'html' }, :as => :entry_amp

  # Oembed
  get '/oembed.:format'                => 'oembed#show', :as => :oembed

  # Pages
  get '/about'                         => 'blogs#about', :as => :about

  # ActivityPub
  get '/.well-known/webfinger' => 'activitypub/webfinger#show', :as => :webfinger
  namespace :activitypub do
    post '/inbox/:user_id'                 => 'inboxes#index',       constraints: { user_id: /\d+/ },                     :as => :inbox
    get  '/entry/:user_id/:entry_id'       => 'entries#show',        constraints: { user_id: /\d+/, entry_id: /\d+/ },    :as => :entry
    get  '/activity/:user_id/:activity_id' => 'activities#show',     constraints: { user_id: /\d+/, activity_id: /\d+/ }, :as => :activity
    get  '/outbox/:user_id'                => 'outboxes#index',      constraints: { user_id: /\d+/ },                     :as => :outbox
    get  '/outbox/:user_id/:page'          => 'outboxes#activities', constraints: { user_id: /\d+/, page: /\d+/ },        :as => :outbox_activities
    get  '/user/:user_id'                  => 'profiles#show',       constraints: { user_id: /\d+/ },                     :as => :profile
  end

  # Miscellaneous
  get '/healthz'                       => 'health#show', :as => :health_check
  get 'robots.:format'                 => 'robots#show', defaults: { format: 'txt' }
  get '*unmatched_route', to: 'errors#file_not_found'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
