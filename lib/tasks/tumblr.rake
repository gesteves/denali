namespace :tumblr do
  desc 'Update descriptions of Tumblr photos'
  task :update_all => :environment do


    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    total_posts = ENV['TOTAL_POSTS'].present? ? ENV['TOTAL_POSTS'].to_i : tumblr.blog_info(ENV['TUMBLR_DOMAIN'])['blog']['posts']
    offset = 0
    limit = 20
    updated = 0

    while offset <= total_posts
      puts "Fetching posts #{offset + 1}-#{offset + limit}, out of #{total_posts}"
      posts = tumblr.posts(ENV['TUMBLR_DOMAIN'], offset: offset, limit: limit)['posts']

      posts.each do |post|
        url = post['source_url'] || post['link_url']
        tumblr_id = post['id']

        next if url.blank?

        entry = begin
          Entry.find_by_url(url: url.gsub('https://href.li/?', ''))
        rescue
          nil
        end

        next if entry.blank?

        seconds = 15 * updated
        TumblrUpdateWorker.perform_in(seconds.seconds, entry.id, tumblr_id)
        updated += 1
      end
      offset += limit
      sleep 1
    end
  end

end
