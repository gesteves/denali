class CloudfrontInvalidationWorker < ApplicationWorker
  def perform(entry_id)
    return if entry_id.blank?
    return if !Rails.env.production?
    entry = Entry.find(entry_id)
    entry.touch
    client = Aws::CloudFront::Client.new(access_key_id: ENV['aws_access_key_id'], secret_access_key: ENV['aws_secret_access_key'], region: ENV['s3_region'])
    paths = [entry.permalink_path].compact
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
