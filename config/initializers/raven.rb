if ENV['SENTRY_DSN'].present?
  Raven.configure do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.environments = ['staging', 'production']
    config.excluded_exceptions += ['UnprocessedPhotoError', 'Aws::CloudFront::Errors::TooManyInvalidationsInProgress']
  end
end
