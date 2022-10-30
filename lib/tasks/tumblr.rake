namespace :tumblr do
  desc 'Update descriptions of Tumblr photos'
  task :update_all => :environment do


    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    total_posts = if ENV['QUEUED'].present?
      tumblr.blog_info(ENV['TUMBLR_DOMAIN'])['blog']['queue']
    else
      tumblr.blog_info(ENV['TUMBLR_DOMAIN'])['blog']['posts']
    end
    offset = 0
    limit = 20
    counter = 0

    while offset <= total_posts
      puts "Fetching posts #{offset + 1}-#{offset + limit}, out of #{total_posts}"
      posts = if ENV['QUEUED'].present?
        tumblr.queue(ENV['TUMBLR_DOMAIN'], offset: offset, limit: limit)['posts']
      else
        tumblr.posts(ENV['TUMBLR_DOMAIN'], offset: offset, limit: limit)['posts']
      end

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

        TumblrUpdateWorker.perform_in(counter.minutes, entry.id, tumblr_id, ENV['QUEUED'].blank?)
        counter += 1
      end

      offset += limit
    end
  end

end
