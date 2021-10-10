class GoogleVisionWorker < ApplicationWorker

  def perform(photo_id)
    return if ENV['google_api_key'].blank?

    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.processed?

    response = request_annotations(photo)
    response_colors = response['responses']&.first&.dig('imagePropertiesAnnotation', 'dominantColors', 'colors')
    raise "No colors found" if response_colors.blank?

    photo.dominant_color = dominant_color(response_colors)
    photo.color = is_color?(response_colors)
    photo.black_and_white = is_black_and_white?(response_colors)
    photo.save
  end

  private
  def request_annotations(photo)
    payload = {
      requests: [
        {
          image: {
            source: {
              'imageUri': photo.url(width: 1024, fm: 'jpg')
            }
          },
          features: [
            {
              type: 'IMAGE_PROPERTIES'
            }
          ]
        }
      ]
    }
    response = HTTParty.post("https://vision.googleapis.com/v1/images:annotate?key=#{ENV['google_api_key']}", body: payload.to_json, headers: { 'Content-Type': 'application/json' }, timeout: 120)
    raise "Failed to annotate images: #{response.body}" if response.code >= 400
    JSON.parse(response.body)
  end

  def dominant_color(colors)
    return if colors.blank?
    color = colors.sort { |a, b| b['score'] <=> a['score'] }.first['color']
    to_hex(color)
  end

  def to_hex(color)
    return if color['red'].blank? || color['green'].blank? || color['blue'].blank?
    red = color['red'].to_s(16).rjust(2, '0')
    green = color['green'].to_s(16).rjust(2, '0')
    blue = color['blue'].to_s(16).rjust(2, '0')
    "##{red}#{green}#{blue}".upcase
  end

  def is_color?(colors)
    return if colors.blank?
    colors.any? { |c| c['color']['red'] != c['color']['green'] || c['color']['red'] != c['color']['blue'] || c['color']['green'] != c['color']['blue'] }
  end

  def is_black_and_white?(colors)
    return if colors.blank?
    !is_color?(colors)
  end
end
