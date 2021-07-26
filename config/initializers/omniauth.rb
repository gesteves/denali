OmniAuth.config.logger = Rails.logger

Rails.application.config.middleware.use OmniAuth::Builder do
  opts = {
    scope: 'userinfo.email, userinfo.profile'
  }
  opts[:hd] = ENV['google_apps_domain'] if ENV['google_apps_domain'].present?
  provider :google_oauth2, ENV['google_client_id'], ENV['google_client_secret'], opts
end
OmniAuth.config.allowed_request_methods = %i[get]
