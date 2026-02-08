namespace :flickr do
  desc 'Update titles & descriptions of Flickr photos'
  task :update_all, [:user_id] => :environment do |_task, args|
    next if ENV['FLICKR_CONSUMER_KEY'].blank? || ENV['FLICKR_CONSUMER_SECRET'].blank?

    user = args[:user_id].present? ? User.find(args[:user_id]) : User.first
    flickr_account = user.flickr_account
    next if flickr_account.blank?

    flickr = FlickRaw::Flickr.new(ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET'])
    flickr.access_token = flickr_account.access_token
    flickr.access_secret = flickr_account.access_token_secret

    flickr_user_id = flickr.auth.oauth.checkToken.user.nsid
    flickr_user = flickr.people.getInfo(user_id: flickr_user_id)
    pages = (flickr_user.photos.count/500.00).ceil
    page = 1

    while page <= pages
      puts "Fetching page #{page} of Flickr photos, out of #{pages}"
      photos = flickr.people.getPublicPhotos(user_id: flickr_user_id, extras: 'description', per_page: 500, page: page)
      photos.select { |p| p.description.match? ENV['DOMAIN'] }.each do |p|
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
        FlickrUpdateJob.perform_async(photo_id, flickr_id)
      end
      page += 1
    end
  end

end
