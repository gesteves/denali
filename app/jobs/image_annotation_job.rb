class ImageAnnotationJob < ApplicationJob
  queue_as :default

  def perform(photo)
    response = request_annotations(photo)
    response_labels = response['responses'].try(:first).try(:[], 'labelAnnotations')
    response_colors = response['responses'].try(:first).dig('imagePropertiesAnnotation', 'dominantColors', 'colors')

    photo.keywords = labels(response_labels)
    photo.dominant_color = dominant_color(response_colors)
    photo.color = is_color?(response_colors)
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
              type: 'LABEL_DETECTION'
            },
            {
              type: 'IMAGE_PROPERTIES'
            }
          ]
        }
      ]
    }
    request = HTTParty.post("https://vision.googleapis.com/v1/images:annotate?key=#{ENV['google_api_key']}", body: payload.to_json, headers: { 'Content-Type' => 'application/json' }, timeout: 120)
    raise request.code if request.code != 200
    JSON.parse(request.body)
  end

  def labels(labels, opts = {})
    opts.reverse_merge!(min_score: 0.8)
    return if labels.blank? || labels.select { |l| l['score'] >= opts[:min_score] }.empty?
    labels.select { |l| l['score'] >= opts[:min_score] }.map { |l| l['description'] }.join(', ')
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

  def is_color?(colors, opts = {})
    return false if colors.blank?
    !colors.reject { |c| (c['color']['red'] - c['color']['green']).abs <= 1 && ((c['color']['red'] - c['color']['blue']).abs <= 1) && ((c['color']['green'] - c['color']['blue']).abs <= 1) }.empty?
  end
end
