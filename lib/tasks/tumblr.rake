namespace :tumblr do
  desc 'Update descriptions of Tumblr photos'
  task :update => :environment do

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    total_posts = if ENV['POST_LIMIT'].present?
      ENV['POST_LIMIT'].to_i
    elsif ENV['UPDATE_QUEUE'].present?
      tumblr.blog_info(ENV['TUMBLR_DOMAIN'])['blog']['queue']
    else
      tumblr.blog_info(ENV['TUMBLR_DOMAIN'])['blog']['posts']
    end

    limit = [20, total_posts].min
    updated = 0

    puts "Updating #{total_posts} Tumblr#{ENV['UPDATE_QUEUE'].present? ? ' queued ' : ' '}posts in #{ENV['TUMBLR_DOMAIN']}."
    
    while updated < total_posts
      puts "  Fetching posts #{updated + 1}-#{updated + limit}…"
      posts = if ENV['UPDATE_QUEUE'].present?
        tumblr.queue(ENV['TUMBLR_DOMAIN'], offset: updated, limit: [total_posts - updated, limit].min)['posts']
      else
        tumblr.posts(ENV['TUMBLR_DOMAIN'], offset: updated, limit: [total_posts - updated, limit].min, type: 'photo')['posts']
      end

      posts.each do |post|
        next if post['type'] != 'photo'
        
        tumblr_id = post['id']
        post_url = post['post_url']
        source_url = post['source_url']
        caption = post['caption']
        caption_url = Nokogiri::HTML.fragment(caption)&.css('a')&.select { |a| a.attr('href')&.match? ENV['DOMAIN'] }&.first&.attr('href')
        url = caption_url || source_url

        entry = begin
          Entry.find_by_url(url: url&.gsub('https://href.li/?', ''))
        rescue
          nil
        end

        seconds = 10 * updated
        updated += 1
        TumblrUpdateWorker.perform_in(seconds.seconds, entry.id, tumblr_id) unless entry.blank?
      end
      sleep 1
    end
    puts "Queued #{updated} Tumblr posts to be updated."
  end

end
