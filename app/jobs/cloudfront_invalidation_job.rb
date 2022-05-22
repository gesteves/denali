class CloudfrontInvalidationJob < ApplicationJob
  queue_as :default

  def perform(entry)
    return if !Rails.env.production?
    client = Aws::CloudFront::Client.new(access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'], region: ENV['S3_REGION'])
    paths = [entry.permalink_path, entry.amp_path].compact
    response = client.create_invalidation({
      distribution_id: ENV['aws_cloudfront_distribution_id'],
      invalidation_batch: {
        paths: {
          quantity: paths.size,
          items: paths,
        },
        caller_reference: Time.current.to_i.to_s,
      },
    })
  end
end
