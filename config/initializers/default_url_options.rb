host = if Rails.env.production?
  ENV['domain'] || "#{ENV['HEROKU_APP_NAME']}.herokuapp.com"
else
  'localhost'
end

protocol = Rails.application.config.force_ssl ? 'https' : 'http'

Rails.application.routes.default_url_options.merge!(
  host: host,
  protocol: protocol,
)
