Bugsnag.configure do |config|
  config.api_key = ENV['BUGSNAG_API_KEY']
  config.app_version = ENV['FLY_MACHINE_VERSION']
  config.discard_classes += %w{
    ActiveRecord::RecordNotFound
    Aws::CloudFront::Errors::ServiceUnavailable
    Aws::CloudFront::Errors::TooManyInvalidationsInProgress
    UnprocessedPhotoError
  }
end
