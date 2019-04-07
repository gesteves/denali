class PhotoKeywordsWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    labels = detect_labels(photo)
    photo.keywords = labels.map(&:name).join(', ')
    photo.save!
  end

  private
  def detect_labels(photo)
    credentials = Aws::Credentials.new(ENV['aws_access_key_id'], ENV['aws_secret_access_key'])
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
