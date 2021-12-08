namespace :flickr do
  desc 'Update titles & descriptions of Flickr photos'
  task :update_meta => :environment do
    next if ENV['flickr_consumer_key'].blank? || ENV['flickr_consumer_secret'].blank? || ENV['flickr_access_token'].blank? || ENV['flickr_access_token_secret'].blank?

    flickr = FlickRaw::Flickr.new(ENV['flickr_consumer_key'], ENV['flickr_consumer_secret'])
    flickr.access_token = ENV['flickr_access_token']
    flickr.access_secret = ENV['flickr_access_token_secret']

    user_id = flickr.auth.oauth.checkToken.user.nsid
    user = flickr.people.getInfo(user_id: user_id)
    pages = (user.photos.count/500.00).ceil
    page = 1

    while page <= pages
      puts "Fetching page #{page} of Flickr photos, out of #{pages}"
      photos = flickr.people.getPublicPhotos(user_id: user_id, extras: 'description', per_page: 500, page: page)
      photos.select { |p| p.description.match? ENV['domain'] }.each do |p|
        flickr_id = p.id
        description = p.description

        url = Nokogiri::HTML.fragment(description)&.css('a')&.first&.attr('href')
        next if url.blank?

        entry = begin
          Entry.find_by_url(url: url)
        rescue
          nil
        end

        next unless entry&.is_single_photo?

        photo_id = entry.photos.first.id
        FlickrSetMetaWorker.perform_async(photo_id, flickr_id)
      end
      page += 1
    end
  end

end
