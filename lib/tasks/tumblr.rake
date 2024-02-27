namespace :tumblr do
  namespace :update do
    desc 'Update published Tumblr posts'
    task :entries => :environment do
      Entry.posted_on_tumblr.each_with_index do |entry, i|
        seconds = i * 10
        TumblrUpdateWorker.perform_in(seconds.seconds, entry.id) unless ENV['DRY_RUN'].present?
      end
    end

    desc 'Update Tumblr IDs and reblog keys'
    task :ids => :environment do
      tumblr = Tumblr::Client.new({
        consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
        consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
        oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
        oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
      })

      tumblr_username = Blog.first.tumblr_username
      next if tumblr_username.blank?

      total_posts = tumblr.blog_info(tumblr_username)['blog']['posts']

      limit = 50
      offset = 0
      updated = 0

      puts "Updating Tumblr post IDs and reblog keys"

      while offset < total_posts
        puts "  Fetching posts #{offset + 1}-#{offset + limit}…"
        response = tumblr.posts(tumblr_username, offset: offset, limit: limit, type: 'photo', reblog_info: true)

        if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
          puts response.to_s
          break
        end

        posts = response['posts']

        posts.each do |post|
          next if post['reblogged_from_id'].present?
          tumblr_id = post['id_string']
          reblog_key = post['reblog_key']
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
            entry.tumblr_id = tumblr_id
            entry.tumblr_reblog_key = reblog_key
            entry.save!
            updated += 1
            puts "    Set Tumblr ID #{tumblr_id} and reblog key #{reblog_key} for entry #{entry.id}"
          end
        end
        offset += posts.size
      end
      puts "Updated Tumblr IDs and reblog keys on #{updated} entries, out of #{total_posts} Tumblr posts."
    end

    desc 'Update Tumblr IDs and reblog keys of queued posts'
    task :queued_ids => :environment do
      tumblr = Tumblr::Client.new({
        consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
        consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
        oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
        oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
      })

      tumblr_username = Blog.first.tumblr_username
      next if tumblr_username.blank?

      total_posts = tumblr.blog_info(tumblr_username)['blog']['queue']

      limit = 50
      offset = 0
      updated = 0

      puts "Updating Tumblr post IDs and reblog keys"

      while offset < total_posts
        puts "  Fetching posts #{offset + 1}-#{offset + limit}…"
        response = tumblr.queue(tumblr_username, offset: offset, limit: limit)

        if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
          puts response.to_s
          break
        end

        posts = response['posts']

        posts.each do |post|
          tumblr_id = post['id_string']
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
            entry.tumblr_id = tumblr_id
            entry.save
            TumblrMetadataWorker.perform_async(entry.id)
            updated += 1
            puts "    Enqueued reblog key job for entry #{entry.id}"
          end
        end
        offset += posts.size
      end
      puts "Updated Tumblr IDs and reblog keys on #{updated} entries, out of #{total_posts} queued Tumblr posts."
    end
  end

  namespace :delete do
    desc 'Update Tumblr IDs and reblog keys'
    task :posts => :environment do
      tumblr = Tumblr::Client.new({
        consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
        consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
        oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
        oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
      })

      tumblr_username = Blog.first.tumblr_username
      next if tumblr_username.blank?

      total_posts = tumblr.blog_info(tumblr_username)['blog']['posts']

      limit = 50
      offset = 0

      puts "Deleting #{total_posts} Tumblr posts"

      while offset < total_posts
        puts "  Fetching posts #{offset + 1}-#{offset + limit}…"
        response = tumblr.posts(tumblr_username, offset: offset, limit: limit, type: 'photo', reblog_info: true)

        if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
          puts response.to_s
          break
        end

        posts = response['posts']

        posts.each do |post|
          tumblr_id = post['id_string']
          puts "Enqueing job to delete tumblr post #{tumblr_id}"
          TumblrDeleteWorker.perform_async(tumblr_username, tumblr_id)
        end
      end
    end
  end
end
