Bugsnag.configure do |config|
  config.api_key = ENV['BUGSNAG_API_KEY']
  config.enabled_release_stages = %w[production]
  config.discard_classes += %w{
    ActiveRecord::RecordNotFound
    UnprocessedPhotoError
  }
end
