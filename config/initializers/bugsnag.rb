Bugsnag.configure do |config|
  config.api_key = ENV['BUGSNAG_API_KEY']
  config.app_version = ENV['HEROKU_RELEASE_VERSION'] || ENV['RENDER_GIT_COMMIT'] || ENV['FLY_ALLOC_ID']
  config.discard_classes += %w{
    ActiveRecord::RecordNotFound
    Aws::CloudFront::Errors::ServiceUnavailable
    Aws::CloudFront::Errors::TooManyInvalidationsInProgress
    TumblrPostDelayedPublishError
    UnprocessedPhotoError
  }
end
