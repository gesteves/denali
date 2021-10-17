require 'open-uri'
class PhotoIptcWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.processed?

    blob = URI.open(photo.image.url).binmode.read
    iptc = IPTC::JPEG::Image.from_blob(blob)
    keywords = iptc&.values['iptc/Keywords']&.value
    park_code = keywords&.find { |k| k.downcase.start_with? 'nps:' }
    if park_code.present?
      photo.park_code = park_code.downcase.gsub('nps:', '')
      photo.save!
    end
  end
end
