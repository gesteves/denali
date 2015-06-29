class CloudfrontInvalidationJob < ActiveJob::Base

  queue_as :default

  def perform(entry)
    invalidator = CloudfrontInvalidator.new(ENV['aws_access_key_id'], ENV['aws_secret_access_key'], ENV['aws_cloudfront_distribution_id'])
    invalidator.invalidate(permalink_path(entry))
  end

  def permalink_path(entry)
    year, month, day, id, slug = entry.slug_params
    Rails.application.routes.url_helpers.entry_long_path(year, month, day, id, slug)
  end
end
