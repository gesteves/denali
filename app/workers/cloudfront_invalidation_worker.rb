class CloudfrontInvalidationWorker < ApplicationWorker
  def perform(paths = ['/*'])
    paths = [paths].flatten.uniq.reject(&:blank?).reject { |path| !path.start_with? '/' }
    return if ENV['CACHE_TTL'].to_i <= 60
    return if paths.blank?
    return if !Rails.env.production?
    client = Aws::CloudFront::Client.new(access_key_id: ENV['aws_access_key_id'], secret_access_key: ENV['aws_secret_access_key'], region: ENV['s3_region'])
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
