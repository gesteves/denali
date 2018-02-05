class ImageAnnotationJob < ApplicationJob
  queue_as :default

  def perform(photo)
    response = request_annotations(photo)
    label_array = response['responses'].try(:first).try(:[], 'labelAnnotations')
    color_array = response['responses'].try(:first).dig('imagePropertiesAnnotation', 'dominantColors', 'colors')
    labels = extract_labels(label_array)
    dominant_color = extract_dominant_color(color_array)
    is_color = is_color? label_array

    photo.keywords = labels
    photo.dominant_color = dominant_color
    photo.color = is_color
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
    JSON.parse(request.body)
  end

  def extract_labels(labels, opts = {})
    opts.reverse_merge!(min_score: 0.85)
    return if labels.blank?
    labels.select { |l| l['score'] >= opts[:min_score] }.map { |l| l['description'] }.join(', ')
  end

  def extract_dominant_color(colors)
    return if colors.blank?
    color = colors.sort { |a, b| b['score'] <=> a['score'] }.first['color']
    to_hex(color)
  end

  def to_hex(color)
    red = color['red'].to_s(16).rjust(2, '0')
    green = color['green'].to_s(16).rjust(2, '0')
    blue = color['blue'].to_s(16).rjust(2, '0')
    "##{red}#{green}#{blue}".upcase
  end

  def is_color?(labels, opts = {})
    opts.reverse_merge!(min_score: 0.85)
    labels.select { |l| l['score'] >= opts[:min_score] }.select { |l| l['description'].match? /(black and white|monochrome)/ }.empty?
  end
end
