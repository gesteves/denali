class NationalParkWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    return if photo.location.blank?
    return if ENV['nps_api_key'].blank?
    raise UnprocessedPhotoError unless photo.processed?

    return if ENV['nps_api_key'].blank?

    park = Park.find_by_code(photo.location&.downcase)

    if park.present?
      photo.park = park
      photo.save!
    else
      url = "https://developer.nps.gov/api/v1/parks?parkCode=#{photo.location&.downcase}&api_key=#{ENV['nps_api_key']}"
      response = HTTParty.get(url)
      raise if response.code >= 400

      data = JSON.parse(response.body)['data']
      park = data&.find { |p| p['parkCode'].downcase == photo.location }
      if park.present?
        photo.park = Park.create_with(
          full_name: park['fullName'],
          short_name: park['name'],
          code: park['parkCode'].downcase,
          designation: park['designation'],
          url: park['url'],
          slug: park['fullName'].parameterize
        ).find_or_create_by(code: park['parkCode'].downcase)
      else
        photo.park = nil
      end
      photo.save!
    end
  end
end
