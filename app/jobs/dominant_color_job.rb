class DominantColorJob < ApplicationJob
  queue_as :default

  def perform(photo)
    color = dominant_color(photo)
    if color.present?
      hex = "##{to_hex(color['red'])}#{to_hex(color['green'])}#{to_hex(color['blue'])}"
      photo.dominant_color = hex
      photo.save
    end
  end

  private

  def dominant_color(photo)
    payload = {
      requests: [
        {
          image: {
            content: Base64.encode64(open(photo.url(width: 640)).read)
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
    JSON.parse(request.body).try(:[], 'responses').try(:[], 0).try(:[], 'imagePropertiesAnnotation').try(:[], 'dominantColors').try(:[], 'colors').try(:first).try(:[], 'color')
  end

  def to_hex(number)
    number = (number * 255).float if number < 1
    number.to_s(16).rjust(2, '0')
  end
end
