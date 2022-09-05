if Rails.env.production?
  host = if ENV['RENDER'] && ENV['IS_PULL_REQUEST'] == 'true'
    ENV['RENDER_EXTERNAL_HOSTNAME']
  else
    ENV['DOMAIN']
  end
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
