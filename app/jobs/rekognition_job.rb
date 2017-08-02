class RekognitionJob < ApplicationJob
  queue_as :default

  def perform(entry)
    entry.keyword_list = entry.photos.map { |p| rekognize(p) }.flatten.uniq
    entry.save
  end

  def rekognize(photo)
    begin
      credentials = Aws::Credentials.new(ENV['aws_access_key_id'], ENV['aws_secret_access_key'])
      client = Aws::Rekognition::Client.new(credentials: credentials, region: 'us-east-1')
      opts = {
        image: {
          s3_object: {
            bucket: ENV['s3_bucket'],
            name: photo.image.path,
          }
        },
        min_confidence: 80
      }
      client.detect_labels(opts).labels.map(&:name)
    rescue
      []
    end
  end
end
