Bugsnag.configure do |config|
  config.api_key = ENV['BUGSNAG_API_KEY']
  config.app_version = ENV['HEROKU_RELEASE_VERSION'] || ENV['RENDER_GIT_COMMIT'] || ENV['FLY_ALLOC_ID']
  config.discard_classes += ['UnprocessedPhotoError', 'TumblrPostDelayedPublishError', 'Aws::CloudFront::Errors::TooManyInvalidationsInProgress']
end
