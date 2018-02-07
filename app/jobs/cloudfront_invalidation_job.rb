class CloudfrontInvalidationJob < ApplicationJob
  include Rails.application.routes.url_helpers
  queue_as :default

  def perform(entry)
    return if !Rails.env.production?
    client = Aws::CloudFront::Client.new(access_key_id: ENV['aws_access_key_id'], secret_access_key: ENV['aws_secret_access_key'], region: ENV['s3_region'])
    paths = if entry.is_published?
      [entry.permalink_path]
    elsif entry.is_draft? || entry.is_queued?
      [preview_entry_path(entry.preview_hash)]
    end
    response = client.create_invalidation({
      distribution_id: ENV['aws_cloudfront_distribution_id'],
      invalidation_batch: {
        paths: {
          quantity: paths.size,
          items: paths,
        },
        caller_reference: Time.now.to_i.to_s,
      },
    })
  end
end
