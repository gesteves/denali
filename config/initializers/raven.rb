if ENV['sentry_dsn'].present?
  Raven.configure do |config|
    config.dsn = ENV['sentry_dsn']
    config.environments = ['staging', 'production']
    config.excluded_exceptions += ['UnprocessedPhotoError', 'RetrySidekiq']
  end
end
