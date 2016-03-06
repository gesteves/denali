class DominantColorJob < ApplicationJob
  queue_as :default

  def perform(photo)
    color = dominant_color(photo)
    if color.present?
      photo.dominant_color = to_hex(color)
      photo.save!
    end
  end

  private

  def dominant_color(photo)
    payload = {
      requests: [
        {
          image: {
            content: Base64.encode64(open(photo.url(width: 640, auto: 'compress')).read)
          },
          features: [
            {
              type: 'IMAGE_PROPERTIES',
              maxResults: 10
            }
          ]
        }
      ]
    }
    request = HTTParty.post("https://vision.googleapis.com/v1/images:annotate?key=#{ENV['vision_api_key']}", body: payload.to_json, headers: { 'Content-Type' => 'application/json' }, timeout: 120)
    color = JSON.parse(request.body).try(:[], 'responses').try(:[], 0).try(:[], 'imagePropertiesAnnotation').try(:[], 'dominantColors').try(:[], 'colors').try(:first).try(:[], 'color')
    error = JSON.parse(request.body)['error']
    if color.present?
      color
    elsif error.present?
      raise error['message']
    end
  end

  def to_hex(color)
    red = color['red'].to_s(16).rjust(2, '0')
    green = color['green'].to_s(16).rjust(2, '0')
    blue = color['blue'].to_s(16).rjust(2, '0')
    "##{red}#{green}#{blue}".upcase
  end
end
