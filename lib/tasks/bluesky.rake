namespace :bluesky do
  desc "Post a thread to Bluesky from a YAML file"
  task skeet: :environment do

    file_path = Rails.root.join('config', 'skeets.yml')
    unless File.exist?(file_path)
      puts "YAML file not found at #{file_path}"
      exit(1)
    end

    # Load posts from YAML file and symbolize keys
    posts_data = YAML.load_file(file_path).deep_symbolize_keys[:posts]
    if posts_data.blank? || !posts_data.is_a?(Array)
      puts "Invalid or empty YAML structure in #{file_path}"
      exit(1)
    end

    # Initialize Bluesky instance
    base_url = ENV.fetch("BLUESKY_BASE_URL")
    email = ENV.fetch("BLUESKY_EMAIL")
    password = ENV.fetch("BLUESKY_PASSWORD")
    bluesky = Bluesky.new(base_url: base_url, email: email, password: password)

    # Initialize variables to keep track of the thread
    root_post = nil
    parent_post = nil
    entry = nil

    posts_data.each_with_index do |post_data, index|
      text = post_data[:text]
      entry_id = post_data[:entry_id]
      photos = post_data[:photos] || []

      next if text.blank?

      if entry_id.present?
        entry = Entry.published.find_by(id: entry_id)

        if entry&.is_photo?
          photos = entry.photos.to_a[0..4].map do |p|
            {
              url: p.bluesky_url,
              alt_text: p.alt_text,
              width: p.width,
              height: p.height
            }
          end
        end
      end

      reply_to = {}
      if root_post
        reply_to[:root] = {
          uri: root_post[:uri],
          cid: root_post[:cid]
        }
        reply_to[:parent] = {
          uri: parent_post[:uri],
          cid: parent_post[:cid]
        }
      end

      puts "Posting #{index + 1}/#{posts_data.size}: #{text.truncate(50)}"
      begin
        response = bluesky.skeet(text: text, photos: photos, reply_to: reply_to)
        root_post ||= { uri: response["uri"], cid: response["cid"] }
        parent_post = { uri: response["uri"], cid: response["cid"] }
        entry&.update!(last_shared_on_bluesky_at: Time.current)
      rescue => e
        puts "Failed to post ##{index + 1}: #{e.message}"
        break
      end
    end
  end
end
