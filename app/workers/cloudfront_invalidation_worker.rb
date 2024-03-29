class CloudfrontInvalidationWorker < ApplicationWorker
  def perform(paths)
    paths = [paths].flatten.reject(&:blank?).reject { |path| !path.start_with? '/' }.uniq.sort.each_slice(15).to_a
    return if ENV['CACHE_TTL'].to_i <= 1
    return if paths.blank?
    return if !Rails.env.production?

    if paths.size == 1
      create_invalidation(paths.flatten)
    else
      paths.each { |p| CloudfrontInvalidationWorker.perform_async(p) }
    end
  end

  private

  def create_invalidation(paths)
    return if paths.blank?
    client = Aws::CloudFront::Client.new(access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'], region: ENV['S3_REGION'])

    client.create_invalidation({
      distribution_id: ENV['AWS_CLOUDFRONT_DISTRIBUTION_ID'],
      invalidation_batch: {
        paths: {
          quantity: paths.size,
          items: paths,
        },
        caller_reference: caller_reference(paths),
      },
    })
  end

  def caller_reference(paths)
    sha256 = Digest::SHA256.new
    sha256.hexdigest([paths, Time.current.to_i.to_s, rand.to_s].flatten.join(' ').parameterize)
  end
end
