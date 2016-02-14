Rails.application.routes.draw do

  concern :paginatable do
    get '(page/:page)', :action => :index, :on => :collection, :as => ''
  end

  namespace :admin do
    get '/tagged/:tag(/page/:page)'   => 'entries#tagged', constraints: { page: /\d+/ }, :as => 'tag'
    get 'settings'                    => 'blogs#edit'
    patch 'settings/update'           => 'blogs#update'
    get '/slack(/page/:page)'         => 'slack_incoming_webhooks#index',  constraints: { page: /\d+/ }, :as => :slack

    resources :entries, only: [:index, :new, :create, :edit, :update, :destroy], concerns: :paginatable do
      member do
        get 'preview'
        get 'share'
        patch 'publish'
        patch 'queue'
        patch 'draft'
        post 'up'
        post 'down'
        post 'top'
        post 'bottom'
        post 'tweet'
        post 'facebook'
      end
      collection do
        get 'queued'
        get 'drafts'
        get 'photo'
      end
    end
  end


  get '/page/:page'                    => 'entries#index',  constraints: { page: /\d+/ }, :as => :entries
  get '/count/:count'                  => 'entries#index',  constraints: { count: /\d+/ }
  get '/tagged/:tag(/page/:page)'      => 'entries#tagged', constraints: { page: /\d+/ }, :as => :tag
  get '/tagged/:tag(/count/:count)'    => 'entries#tagged', constraints: { count: /\d+/ }
  get '/e/:id'                         => 'entries#show',   constraints: { id: /\d+/ }, :as => :entry
  get '/:year/:month/:day/:id(/:slug)' => 'entries#show',   constraints: { id: /\d+/, year: /\d{1,4}/, month: /\d{1,2}/, day: /\d{1,2}/ }, :as => :entry_long
  get '/post/:tumblr_id(/:slug)'       => 'entries#tumblr', constraints: { tumblr_id: /\d+/ }
  get '/map'                           => 'maps#index', :as => :map
  get '/map/photos.:format'            => 'maps#photos'
  get '/slack'                         => 'slack#index', :as => :slack
  get '/rss'                           => 'entries#rss', defaults: { format: 'xml' }
  get '/sitemap'                       => 'entries#sitemap', defaults: { format: 'xml' }

  get '/about' => 'pages#about', :as => :about

  get '/admin'                    => 'admin#index'
  get '/auth/:provider/callback'  => 'sessions#create'
  get '/auth/failure'             => 'sessions#failure'
  get '/signin'                   => 'sessions#new',     :as => :signin
  get '/signout'                  => 'sessions#destroy', :as => :signout

  root 'entries#index'

  match '/404', to: 'errors#file_not_found', via: :all
  match '/422', to: 'errors#unprocessable', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
end
