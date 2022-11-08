namespace :tumblr do
  desc 'Update descriptions of Tumblr photos'
  task :update => :environment do

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    tumblr_username = Blog.first.tumblr_username
    return if tumblr_username.blank?

    total_posts = if ENV['QUEUE'].present?
      tumblr.blog_info(tumblr_username)['blog']['queue']
    else
      tumblr.blog_info(tumblr_username)['blog']['posts']
    end

    total_limit = ENV['LIMIT'].present? ? ENV['LIMIT'].to_i : total_posts
    limit = 20
    offset = 0
    updated = 0
    skipped = 0

    puts "Updating Tumblr #{ENV['QUEUE'].present? ? ' queued posts' : 'posts'}"
    
    while offset < total_posts
      break if updated >= total_limit
      
      puts "  Fetching posts #{offset + 1}-#{offset + limit}…"
      response = if ENV['QUEUE'].present?
        tumblr.queue(tumblr_username, offset: offset, limit: limit)
      else
        tumblr.posts(tumblr_username, offset: offset, limit: limit, type: 'photo')
      end

      if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
        puts response.to_s
        break
      end

      posts = response['posts']

      posts.each do |post|
        break if updated >= total_limit
        next if post['type'] != 'photo'
        
        tumblr_id = post['id']
        post_url = post['post_url']
        source_url = post['source_url']
        caption = post['caption']

        next if ENV['LOW_RES'].present? && post['photos'].all? { |photo| photo['alt_sizes'].any? { |size| size['width'] == 2048 } }

        caption_url = Nokogiri::HTML.fragment(caption)&.css('a')&.find { |a| a.attr('href')&.match? ENV['DOMAIN'] }&.attr('href')
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

  desc 'Sorts queue chronologically'
  task :sort_queue => :environment do

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    tumblr_username = Blog.first.tumblr_username
    return if tumblr_username.blank?

    total_posts = tumblr.blog_info(tumblr_username)['blog']['queue']

    limit = 20
    offset = 0

    queue = []

    puts "Updating Tumblr #{ENV['QUEUE'].present? ? ' queued posts' : 'posts'}"
    
    while offset < total_posts
      
      puts "  Fetching posts #{offset + 1}-#{offset + limit}…"
      response = tumblr.queue(tumblr_username, offset: offset, limit: limit)

      if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
        puts response.to_s
        break
      end

      posts = response['posts']

      posts.each do |post|
        
        tumblr_id = post['id']
        post_url = post['post_url']
        source_url = post['source_url']
        caption = post['caption']

        caption_url = Nokogiri::HTML.fragment(caption)&.css('a')&.find { |a| a.attr('href')&.match? ENV['DOMAIN'] }&.attr('href')
        url = caption_url || source_url

        entry = begin
          Entry.find_by_url(url: url&.gsub('https://href.li/?', ''))
        rescue
          nil
        end

        queue << { entry_id: entry.id, tumblr_id: tumblr_id, post_url: post_url, published_at: entry.published_at } if entry.present?
      end
      offset += limit
    end

    queue.sort! { |a,b| a[:published_at] <=> b[:published_at] }.each_with_index do |p, i|
      seconds = i * 10
      insert_after = i == 0 ? 0 : queue[i - 1][:tumblr_id]
      TumblrSortQueueWorker.perform_in(seconds.seconds, p[:entry_id], p[:tumblr_id], insert_after)
      puts "Enqueued queue update for post #{p[:post_url]} (#{p[:published_at].strftime('%c')})"
    end
  end

end
