if Rails.env.production?
  host = ENV['DOMAIN']
  protocol = Rails.application.config.force_ssl ? 'https' : 'http'
  Rails.application.routes.default_url_options.merge!(
    host: host,
    protocol: protocol,
  )
else
  Rails.application.routes.default_url_options.merge!(
    host: 'localhost:3000',
    protocol: 'http',
  )
end
