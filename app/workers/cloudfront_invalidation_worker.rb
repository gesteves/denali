class CloudfrontInvalidationWorker < ApplicationWorker
  def perform(paths)
    paths = [paths].flatten.reject(&:blank?).reject { |path| !path.start_with? '/' }.uniq.sort.each_slice(15).to_a
    return if ENV['CACHE_TTL'].to_i <= 1
    return if paths.blank?
    return if !Rails.env.production?
    paths.each { |p| create_invalidation(p, await_completion: !p.equal?(paths.last)) }
  end

  private

  def create_invalidation(paths, await_completion: false)
    return if paths.blank?
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
    invalidation_id = response&.invalidation&.id
    if await_completion && invalidation_id.present?
      while client.get_invalidation({ distribution_id: ENV['aws_cloudfront_distribution_id'], id: invalidation_id })&.invalidation&.status != 'Completed'
        sleep 10.seconds
      end
    end
  end
end
