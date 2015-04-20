Rails.application.routes.draw do
  namespace :admin do
    get 'settings' => 'blogs#edit'
    patch 'settings/update' => 'blogs#update'
  end

  get '/auth/:provider/callback' => 'sessions#create'
  get '/auth/failure'            => 'sessions#failure'
  get '/signin'                  => 'sessions#new',     :as => :signin
  get '/signout'                 => 'sessions#destroy', :as => :signout
end
