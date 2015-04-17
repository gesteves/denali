Rails.application.routes.draw do
  get '/auth/:provider/callback' => 'sessions#create'
  get '/auth/failure'            => 'sessions#failure'
  get '/signin'                  => 'sessions#new',     :as => :signin
  get '/signout'                 => 'sessions#destroy', :as => :signout
end
