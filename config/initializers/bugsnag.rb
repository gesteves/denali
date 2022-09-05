Bugsnag.configure do |config|
  config.api_key = ENV['BUGSNAG_API_KEY']
  config.app_version = ENV['RENDER_GIT_COMMIT'] || ENV['HEROKU_SLUG_COMMIT']
  config.discard_classes += ['UnprocessedPhotoError', 'Aws::CloudFront::Errors::TooManyInvalidationsInProgress']
end
