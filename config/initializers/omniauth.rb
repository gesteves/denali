OmniAuth.config.logger = Rails.logger
Rails.application.config.middleware.use OmniAuth::Builder do
  opts = {
    scope: 'userinfo.email, userinfo.profile',
    skip_jwt: true
  }
  opts[:hd] = ENV['GOOGLE_APPS_DOMAIN'] if ENV['GOOGLE_APPS_DOMAIN'].present?
  provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], opts
end
