namespace :tumblr do
  namespace :update do
    desc 'Update Tumblr posts'
    task :posts => :environment do
      tumblr = Tumblr::Client.new({
        consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
        consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
        oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
        oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
      })

      tumblr_username = Blog.first.tumblr_username
      next if tumblr_username.blank?

      total_posts = if ENV['QUEUE'].present?
        tumblr.blog_info(tumblr_username)['blog']['queue']
      else
        tumblr.blog_info(tumblr_username)['blog']['posts']
      end

      total_limit = ENV['LIMIT'].present? ? ENV['LIMIT'].to_i : total_posts
      limit = 20
      offset = 0
      updated = 0

      puts "Updating Tumblr #{ENV['QUEUE'].present? ? ' queued posts' : 'posts'}"
      
      while offset < total_posts && updated < total_limit
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
          end
        end
        offset += limit
      end
      puts "Enqueued #{updated} Tumblr posts out of #{total_posts} for updates."
    end

    desc 'Update Tumblr posts published in the last 24 hours'
    task :today => :environment do
      tumblr = Tumblr::Client.new({
        consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
        consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
        oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
        oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
      })

      tumblr_username = Blog.first.tumblr_username
      next if tumblr_username.blank?

      total_posts = tumblr.blog_info(tumblr_username)['blog']['posts']
      limit = 20
      offset = 0
      updated = 0
      continue = true

      puts "Updating Tumblr posts published today"
      
      while offset < total_posts && continue
        puts "  Fetching posts #{offset + 1}-#{offset + limit}…"
        response = tumblr.posts(tumblr_username, offset: offset, limit: limit, type: 'photo')

        if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
          puts response.to_s
          break
        end

        posts = response['posts']

        posts.each do |post|
          next if post['type'] != 'photo'
          
          tumblr_id = post['id']
          post_url = post['post_url']
          source_url = post['source_url']
          caption = post['caption']

          if DateTime.parse(post['date']) < 24.hours.ago
            continue = false
            break
          end

          caption_url = Nokogiri::HTML.fragment(caption)&.css('a')&.find { |a| a.attr('href')&.match? ENV['DOMAIN'] }&.attr('href')
          url = caption_url || source_url

          entry = begin
            Entry.find_by_url(url: url&.gsub('https://href.li/?', ''))
          rescue
            nil
          end

          if entry.present?
            TumblrUpdateWorker.perform_async(entry.id, tumblr_id) unless ENV['DRY_RUN'].present?
            puts "    Enqueued update for post #{post_url}"
            updated += 1
          end
        end
        offset += limit
      end
      puts "Enqueued #{updated} Tumblr posts out of #{total_posts} for updates."
    end

    desc 'Update a specific Tumblr post'
    task :entry => :environment do
      next if ENV['ENTRY_ID'].blank?
      tumblr = Tumblr::Client.new({
        consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
        consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
        oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
        oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
      })

      tumblr_username = Blog.first.tumblr_username
      next if tumblr_username.blank?

      total_posts = if ENV['QUEUE'].present?
        tumblr.blog_info(tumblr_username)['blog']['queue']
      else
        tumblr.blog_info(tumblr_username)['blog']['posts']
      end

      limit = 20
      offset = 0
      continue = true

      while offset < total_posts && continue
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
          next if post['type'] != 'photo'
          
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

          if entry.present? && entry.id == ENV['ENTRY_ID'].to_i
            TumblrUpdateWorker.perform_async(entry.id, tumblr_id)
            puts "    Enqueued update for post #{post_url}"
            continue = false
            break
          end
        end
        offset += limit
      end
    end
  end
end
