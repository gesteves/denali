Rails.application.routes.draw do
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
    get '/entries/hashtags/latest'    => 'entries#latest_hashtags', :as => :latest_hashtags
    get '/equipment'                  => 'equipment#index'

    resources :entries, concerns: :paginatable do
      member do
        get 'share'
        get 'crops'
        post 'resize_photos'
        patch 'publish'
        patch 'queue'
        patch 'draft'
        post 'instagram'
        post 'twitter'
        post 'facebook'
        post 'pinterest'
        post 'flickr'
        post 'tumblr'
        post 'flush_caches'
        post 'refresh_metadata'
      end
      collection do
        get 'queued'
        get 'drafts'
        get 'photo'
      end
    end

    resources :tags, only: [:index, :destroy, :show, :update], concerns: :paginatable do
      member do
        post 'add'
      end
    end

    resources :cameras, only: [:edit, :update]
    resources :lenses, only: [:edit, :update]
    resources :films, only: [:edit, :update]
    resources :blogs, only: [:edit, :update]
  end


  get '/(page/:page)'                  => 'entries#index',   constraints: { page: /\d+/ }, defaults: { format: 'html' }, :as => :entries
  get '/tagged/:tag(/page/:page)'      => 'entries#tagged',  constraints: { page: /\d+/ }, defaults: { format: 'html' }, :as => :tag
  get '/search'                        => 'entries#search', :as => :search
  get '/map'                           => 'maps#index', :as => :map
  get '/map/photos.:format'            => 'maps#photos', :as => :map_markers
  get '/map/photo/:id.:format'         => 'maps#photo'
  get '/about'                         => 'blogs#about', :as => :about
  get '/manifest.json'                 => 'blogs#manifest', :as => :app_manifest
  get '/oembed'                        => 'oembed#show', :as => :oembed

  # Entries
  get '/e/:id'                              => 'entries#show',       constraints: { id: /\d+/ }, :as => :entry
  get '/photo/:id'                          => 'entries#photo',      constraints: { id: /\d+/ }, :as => :photo
  get '/related/:id.:format'                => 'entries#related',    constraints: { id: /\d+/ }, :as => :related
  get '/preview/:preview_hash'              => 'entries#preview',    defaults: { format: 'html' }, :as => :preview_entry
  get '/:year/:month/:day/:id(/:slug)'      => 'entries#show',       constraints: { id: /\d+/, year: /\d{1,4}/, month: /\d{1,2}/, day: /\d{1,2}/ }, defaults: { format: 'html' }, :as => :entry_long
  get '/amp/:year/:month/:day/:id(/:slug)'  => 'entries#amp',        constraints: { id: /\d+/, year: /\d{1,4}/, month: /\d{1,2}/, day: /\d{1,2}/ }, defaults: { format: 'html' }, :as => :entry_amp

  # Sitemaps
  get '/sitemap.:format'               => 'entries#sitemap_index', defaults: { format: 'xml' }, :as => :sitemap_index
  get '/sitemap/:page.:format'         => 'entries#sitemap', defaults: { format: 'xml' }, :as => :sitemap

  # Legacy routes & redirects
  get '/post/:tumblr_id(/:slug)'       => 'entries#tumblr', constraints: { tumblr_id: /\d+/ }
  get '/archive(/:year)(/:month)',     to: redirect('/')
  get '/rss',                          to: redirect('/feed.atom')
  get '/service_worker.:format'        => 'errors#file_not_found'

  # Feeds
  get '/feed(.:format)'             => 'entries#feed', defaults: { format: 'atom' }, :as => :feed
  get '/tagged/:tag/feed(.:format)' => 'entries#tag_feed', defaults: { format: 'atom' }, :as => :tag_feed

  # Admin
  get '/admin'                         => 'admin#index',      :as => :admin
  get '/auth/:provider/callback'       => 'sessions#create'
  get '/auth/failure'                  => 'sessions#failure'
  get '/signin'                        => 'sessions#new',     :as => :signin
  get '/signout'                       => 'sessions#destroy', :as => :signout

  # The rest
  get 'robots.:format'                 => 'robots#show', defaults: { format: 'txt' }
  root 'entries#index'
  match '/404', to: 'errors#file_not_found', via: :all
  match '/422', to: 'errors#unprocessable', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
