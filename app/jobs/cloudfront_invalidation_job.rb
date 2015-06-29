class CloudfrontInvalidationJob < EntryJob

  queue_as :default

  def perform(entry)
    invalidator = CloudfrontInvalidator.new(ENV['aws_access_key_id'], ENV['aws_secret_access_key'], ENV['aws_cloudfront_distribution_id'])
    invalidator.invalidate(permalink_path(entry))
  end
end
