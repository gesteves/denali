require 'exifr/jpeg'
require 'open-uri'
class PhotoExifJob < ApplicationJob

  def perform(photo_id)
    photo = Photo.find(photo_id)
    photo.ensure_analyzed!
    raise UnprocessedPhotoError unless photo.has_dimensions?

    URI.open(photo.image.url) do |original|
      exif = EXIFR::JPEG.new(original)
      if exif.present? && exif.exif?
        camera_make = exif.make&.encode('UTF-8')&.strip
        camera_model = exif.model&.encode('UTF-8')&.strip
        camera_name = "#{camera_make} #{camera_model}".strip
        photo.camera = find_or_create(Camera, camera_name.parameterize, display_name: camera_name, make: camera_make, model: camera_model, is_phone: camera_model.match?(/iphone/i)) if camera_make.present? && camera_model.present?

        lens_make = exif.lens_make&.encode('UTF-8')&.strip || camera_make
        lens_model = exif.lens_model&.encode('UTF-8')&.strip
        lens_name = "#{lens_make} #{lens_model}".strip
        photo.lens = find_or_create(Lens, lens_name.parameterize, display_name: lens_name, make: lens_make, model: lens_model) if lens_make.present? && lens_model.present?

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
          comment_array = exif.user_comment.encode('UTF-8')&.split(/(\n)+/)
          film_make = comment_array.find { |c| c =~ /^film make:/i }&.gsub(/^film make:/i, '')&.strip
          film_type = comment_array.find { |c| c =~ /^film type:/i }&.gsub(/^film type:/i, '')&.strip
          film_type = "#{film_type&.gsub(%r{#{exif.iso_speed_ratings}}i, '')&.strip} #{exif.iso_speed_ratings}" if exif.iso_speed_ratings.present?
          film_name = "#{film_make} #{film_type}"
          photo.film = find_or_create(Film, film_name.parameterize, display_name: film_name, make: film_make, model: film_type) if film_make.present? && film_type.present?

          location = comment_array.find { |c| c =~ /^location:/i }&.gsub(/^location:/i, '')&.strip
          photo.location = location if photo.location.blank? && location.present?

          park_code = comment_array.find { |c| c =~ /^park:/i }&.gsub(/^park:/i, '')&.strip&.downcase
          # The park can also be chosen in the admin, and that choice wins over
          # the one recorded in the file.
          if park_code.present? && photo.park.blank?
            park = Park.find_by(code: park_code)
            if park.present?
              photo.park = park
            else
              NationalParkJob.perform_async(photo_id, park_code)
            end
          end
        end
        if exif.image_description.present? && photo.alt_text.blank?
          photo.alt_text = exif.image_description.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        end
      end
    end
    photo.save!
    # Outside the EXIF branch, since a file with no EXIF needs a description as much as any other,
    # and after the save, so a failed save's retry doesn't ask Claude twice.
    AltTextJob.perform_async(photo_id) if photo.alt_text.blank?
  end

  private

  # The EXIF jobs for a multi-photo upload run at the same time, so two can both
  # miss a new camera and try to create it. The loser gets the unique index's
  # error (or the uniqueness validation's, if the winner committed in between)
  # and picks up the winner's row.
  def find_or_create(model, slug, attributes)
    model.create_with(attributes).find_or_create_by!(slug: slug)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    model.find_by!(slug: slug)
  end
end
