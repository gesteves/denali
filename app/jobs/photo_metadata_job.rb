class PhotoMetadataJob < ApplicationJob
  queue_as :default

  def perform(photo, opts = {})
    opts.reverse_merge!(geocode: true)
    original = open(photo.image.service_url)
    image = MiniMagick::Image.open(original.path)
    image.auto_orient
    photo.width = image.width.to_i
    photo.height = image.height.to_i

    exif = EXIFR::JPEG.new(original)
    if exif.present? && exif.exif?
      camera_name = "#{exif.make} #{exif.model}".strip
      photo.camera = Camera.create_with(display_name: camera_name, make: exif.make, model: exif.model, is_phone: exif.model.match?(/iphone/i)).find_or_create_by(slug: camera_name.parameterize) if camera_name.present?

      lens_name = "#{exif.lens_make} #{exif.lens_model}".strip
      photo.lens = Lens.create_with(display_name: lens_name, make: exif.lens_make, model: exif.lens_model).find_or_create_by(slug: lens_name.parameterize) if lens_name.present?

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
        film_make = comment_array.select{ |c| c =~ /^film make/i }&.first&.gsub(/^film make:/i, '')&.strip
        film_type = comment_array.select{ |c| c =~ /^film type/i }&.first&.gsub(/^film type:/i, '')&.strip
        film_name = "#{film_make} #{film_type}".strip
        photo.film = Film.create_with(display_name: film_name, make: film_make, model: film_type).find_or_create_by(slug: film_name.parameterize) if film_name.present?
      end
    end
    photo.save!
    photo.geocode if opts[:geocode]
  end
end
