class PhotoKeywordsJob < ApplicationJob
  queue_as :default

  def perform(photo)
    labels = detect_labels(photo)
    photo.keywords = labels.map(&:name).join(', ')
    photo.save
  end

  private
  def detect_labels(photo)
    credentials = Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
    client = Aws::Rekognition::Client.new(credentials: credentials, region: 'us-east-1')
    opts = {
      image: {
        s3_object: {
          bucket: ENV['s3_bucket'],
          name: photo.image.key
        }
      },
      min_confidence: 80
    }
    client.detect_labels(opts).labels
  end
end
