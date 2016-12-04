class ImageAnalysisJob < ApplicationJob
  queue_as :default

  def perform(entry)
    tags = []
    entry.photos.each do |p|
      tags << rekognize(p)
    end
    tags.flatten!
    entry.object_list = tags
    entry.save
  end

  def rekognize(photo)
    begin
      credentials = Aws::Credentials.new(ENV['aws_access_key_id'], ENV['aws_secret_access_key'])
      client = Aws::Rekognition::Client.new(credentials: credentials, region: 'us-east-1')
      opts = {
        image: {
          bytes: HTTParty.get(photo.url).body
        },
        max_labels: 10
      }
      opts[:min_confidence] = ENV['rekognition_confidence'].to_f if ENV['rekognition_confidence'].present?
      client.detect_labels(opts).labels.map(&:name)
    rescue
      []
    end
  end
end
