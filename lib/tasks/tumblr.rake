namespace :tumblr do
  desc 'Update descriptions of Tumblr photos'
  task :update => :environment do

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    total_posts = if ENV['LIMIT'].present?
      ENV['LIMIT'].to_i
    elsif ENV['QUEUE'].present?
      tumblr.blog_info(ENV['TUMBLR_DOMAIN'])['blog']['queue']
    else
      tumblr.blog_info(ENV['TUMBLR_DOMAIN'])['blog']['posts']
    end

    limit = [20, total_posts].min
    updated = 0
    offset = 0
    skipped = 0

    puts "Updating #{total_posts} Tumblr#{ENV['QUEUE'].present? ? ' queued ' : ' '}posts in #{ENV['TUMBLR_DOMAIN']}."
    
    while offset < total_posts
      puts "  Fetching posts #{offset + 1}-#{offset + limit}…"
      posts = if ENV['QUEUE'].present?
        tumblr.queue(ENV['TUMBLR_DOMAIN'], offset: offset, limit: limit)['posts']
      else
        tumblr.posts(ENV['TUMBLR_DOMAIN'], offset: offset, limit: limit, type: 'photo')['posts']
      end

      posts.each do |post|
        next if post['type'] != 'photo'
        
        tumblr_id = post['id']
        post_url = post['post_url']
        source_url = post['source_url']
        caption = post['caption']

        next if ENV['LOW_RES'].present? && post['photos'].all? { |photo| photo['alt_sizes'].any? { |size| size['width'] == 2048 } }

        caption_url = Nokogiri::HTML.fragment(caption)&.css('a')&.select { |a| a.attr('href')&.match? ENV['DOMAIN'] }&.first&.attr('href')
        url = caption_url || source_url

        entry = begin
          Entry.find_by_url(url: url&.gsub('https://href.li/?', ''))
        rescue
          nil
        end

        if entry.present?
          seconds = 10 * updated
          TumblrUpdateWorker.perform_in(seconds.seconds, entry.id, tumblr_id) unless ENV['DRY_RUN'].present?
          puts "    Enqueued update for post #{post_url}"
          updated += 1
        else
          puts "    Can't update post #{post_url}, skipping…"
          skipped += 1
        end
      end
      offset += limit
    end
    puts "Enqueued #{updated} Tumblr posts out of #{total_posts} for updates (skipped #{skipped} posts.)"
  end

end
