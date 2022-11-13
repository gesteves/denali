namespace :tumblr do
  namespace :update do
    desc 'Update published Tumblr posts'
    task :entries => :environment do
      Entry.posted_on_tumblr.each_with_index do |entry, i|
        seconds = i * 10
        TumblrUpdateWorker.perform_in(seconds.seconds, entry.id) unless ENV['DRY_RUN'].present?
      end
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

      puts "Updating Tumblr posts published in the past 24 hours"

      while offset < total_posts && continue
        puts "  Fetching posts #{offset + 1}-#{offset + limit}…"
        response = tumblr.posts(tumblr_username, offset: offset, limit: limit, type: 'photo', reblog_info: true)

        if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
          puts response.to_s
          break
        end

        posts = response['posts']

        posts.each do |post|
          if DateTime.parse(post['date']) < 24.hours.ago
            continue = false
            break
          end

          next if post['reblogged_from_id'].present?

          tumblr_id = post['id_string']
          reblog_key = post['reblog_key']
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
            entry.tumblr_id = tumblr_id
            entry.tumblr_reblog_key = reblog_key
            entry.save!
            TumblrUpdateWorker.perform_async(entry.id) unless ENV['DRY_RUN'].present?
            puts "    Enqueued update for post #{post_url}"
            updated += 1
          end
        end
        offset += limit
      end
      puts "Enqueued #{updated} Tumblr posts out of #{total_posts} for updates."
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

      limit = 20
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
        offset += limit
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

      limit = 20
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
            seconds = updated * 10
            TumblrReblogKeyWorker.perform_in(seconds.seconds, entry.id)
            updated += 1
            puts "    Enqueued reblog key job for entry #{entry.id}"
          end
        end
        offset += limit
      end
      puts "Updated Tumblr IDs and reblog keys on #{updated} entries, out of #{total_posts} queued Tumblr posts."
    end
  end
end
