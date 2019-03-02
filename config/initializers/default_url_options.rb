host = if Rails.env.production?
  if ENV['HEROKU_PARENT_APP_NAME'].present?
    "#{ENV['HEROKU_APP_NAME']}.herokuapp.com"
  elsif ENV['domain'].present?
    ENV['domain']
  else
    "#{ENV['HEROKU_APP_NAME']}.herokuapp.com"
  end
else
  ENV['domain'] || 'localhost'
end

protocol = Rails.application.config.force_ssl ? 'https' : 'http'

Rails.application.routes.default_url_options.merge!(
  host: host,
  protocol: protocol,
)
