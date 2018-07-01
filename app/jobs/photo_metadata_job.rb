class PhotoMetadataJob < ApplicationJob
  queue_as :default

  def perform(photo)
    original = open(photo.image.service_url)
    image = MiniMagick::Image.open(original.path)
    image.auto_orient
    photo.width = image.width.to_i
    photo.height = image.height.to_i

    exif = EXIFR::JPEG.new(original)
    if exif.present? && exif.exif?
      photo.make = exif.make
      photo.model = exif.model
      photo.iso = exif.iso_speed_ratings
      photo.taken_at = exif.date_time
      photo.exposure = exif.exposure_time
      photo.f_number = exif&.f_number&.to_f
      photo.focal_length = exif&.focal_length&.to_i
      if exif.gps.present?
        photo.longitude = exif.gps.longitude
        photo.latitude = exif.gps.latitude
      end
      if exif.user_comment.present?
        comment_array = exif.user_comment.split(/(\n)+/).select{ |c| c =~ /^film/i }
        film_make = comment_array.select{ |c| c =~ /^film make/i }
        film_type = comment_array.select{ |c| c =~ /^film type/i }
        photo.film_make = film_make&.first&.gsub(/^film make:/i, '')&.strip
        photo.film_type = film_type&.first&.gsub(/^film type:/i, '')&.strip
      end
    end
    photo.save!
    photo.geocode
  end
end
