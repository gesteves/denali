namespace :export do
  desc 'Export posts to Tumblr'
  task :tumblr => [:environment] do
    limit = ENV['ENTRY_COUNT'] || 125
    if ENV['ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id = ?', ENV['ENTRY_ID'])
    elsif ENV['NEWEST_ENTRY_ID'].present? && ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id <= ? AND id >= ?', ENV['NEWEST_ENTRY_ID'], ENV['OLDEST_ENTRY_ID']).photo_entries.limit(limit)
    elsif ENV['NEWEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id <= ?', ENV['NEWEST_ENTRY_ID']).photo_entries.limit(limit)
    elsif ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id >= ?', ENV['OLDEST_ENTRY_ID']).photo_entries.limit(limit)
    else
      entries = Entry.published('published_at ASC').photo_entries.limit(limit)
    end
    tumblr = Tumblr::Client.new({
      consumer_key: ENV['tumblr_consumer_key'],
      consumer_secret: ENV['tumblr_consumer_secret'],
      oauth_token: ENV['tumblr_access_token'],
      oauth_token_secret: ENV['tumblr_access_token_secret']
    })
    entries.each_with_index do |entry, i|
      opts = {
        tags: entry.tag_list.join(', '),
        slug: entry.slug,
        state: 'published',
        caption: entry.formatted_content,
        link: permalink_url(entry),
        data: entry.photos.map { |p| open(p.original_url).path },
        date: entry.published_at.to_s
      }
      response = tumblr.photo(ENV['tumblr_domain'], opts)
      if response['id'].present?
        puts "Exported #{opts[:link]} (#{i + 1}/#{entries.size})"
      elsif response['errors'].present?
        puts "#{response['errors']} Exporting failed at entry ID #{entry.id}"
        break
      end
    end
  end

  desc 'Export posts to Flickr'
  task :flickr => [:environment] do
    if ENV['ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id = ?', ENV['ENTRY_ID'])
    elsif ENV['NEWEST_ENTRY_ID'].present? && ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id <= ? AND id >= ?', ENV['NEWEST_ENTRY_ID'], ENV['OLDEST_ENTRY_ID']).photo_entries
    elsif ENV['NEWEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id <= ?', ENV['NEWEST_ENTRY_ID']).photo_entries
    elsif ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id >= ?', ENV['OLDEST_ENTRY_ID']).photo_entries
    else
      entries = Entry.published('published_at ASC').photo_entries.limit(limit)
    end

    FlickRaw.api_key = ENV['flickr_consumer_key']
    FlickRaw.shared_secret = ENV['flickr_consumer_secret']

    flickr = FlickRaw::Flickr.new
    flickr.access_token = ENV['flickr_access_token']
    flickr.access_secret = ENV['flickr_access_token_secret']

    entries.each_with_index do |entry, i|
      title = entry.title

      if entry.body.present?
        body = "#{entry.formatted_body}\n\n#{permalink_url(entry)}"
      else
        body = permalink_url(entry)
      end

      tags = entry.tag_list.map { |t| "\"#{t.gsub(/["']/, '')}\"" }.join(' ')

      entry.photos.each do |p|
        begin
          flickr.upload_photo open(p.original_url).path, title: title, description: body, tags: tags
        rescue => e
          puts "Exporting failed at entry ID #{entry.id}: #{e}"
        else
          puts "Exported #{permalink_url(entry)} (#{i + 1}/#{entries.size})"
        end
      end
    end
  end

  desc 'Export posts to 500px'
  task :fivehundredpx => [:environment] do
    if ENV['ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id = ?', ENV['ENTRY_ID'])
    elsif ENV['NEWEST_ENTRY_ID'].present? && ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id <= ? AND id >= ?', ENV['NEWEST_ENTRY_ID'], ENV['OLDEST_ENTRY_ID']).photo_entries
    elsif ENV['NEWEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id <= ?', ENV['NEWEST_ENTRY_ID']).photo_entries
    elsif ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id >= ?', ENV['OLDEST_ENTRY_ID']).photo_entries
    else
      entries = Entry.published('published_at ASC').photo_entries.limit(limit)
    end

    consumer = OAuth::Consumer.new(ENV['fivehundredpx_consumer_key'], ENV['fivehundredpx_consumer_secret'], { site: 'https://api.500px.com' })
    access_token = OAuth::AccessToken.new(consumer, ENV['fivehundredpx_access_token'], ENV['fivehundredpx_access_token_secret'])

    entries.each_with_index do |entry, i|
      opts = {
        name: entry.title,
        tags: entry.tag_list.join(','),
        privacy: 0
      }

      if entry.body.present?
        opts[:description] = "#{entry.plain_body}\n\n#{permalink_url(entry)}"
      else
        opts[:description] = permalink_url(entry)
      end

      entry.photos.each do |p|
        response = access_token.post('https://api.500px.com/v1/photos', opts)
        if response.code == '200'
          body = JSON.parse(response.body)
          opts = {
            upload_key: body['upload_key'],
            photo_id: body['photo']['id'],
            file: File.new(open(p.original_url).path),
            consumer_key: ENV['fivehundredpx_consumer_key'],
            access_key: ENV['fivehundredpx_access_token']
          }
          response = HTTMultiParty.post('http://upload.500px.com/v1/upload', body: opts)
          if response.code == 200
            puts "Exported #{permalink_url(entry)} (#{i + 1}/#{entries.size})"
          else
            puts "Uploading failed at entry ID #{entry.id}: #{response.body}"
          end
        else
          puts "Exporting failed at entry ID #{entry.id}: #{response.body}"
        end
      end
    end
  end

  desc 'Export posts to Pinterest'
  task :pinterest => [:environment] do
    if ENV['ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id = ?', ENV['ENTRY_ID'])
    elsif ENV['NEWEST_ENTRY_ID'].present? && ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id <= ? AND id >= ?', ENV['NEWEST_ENTRY_ID'], ENV['OLDEST_ENTRY_ID']).photo_entries
    elsif ENV['NEWEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id <= ?', ENV['NEWEST_ENTRY_ID']).photo_entries
    elsif ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.published('published_at ASC').where('id >= ?', ENV['OLDEST_ENTRY_ID']).photo_entries
    else
      entries = Entry.published('published_at ASC').photo_entries.limit(limit)
    end

    entries.each_with_index do |entry, i|
      opts = {
        board: ENV['pinterest_board_id'],
        note: entry.title,
        link: permalink_url(entry)
      }
      entry.photos.each do |p|
        opts[:image_url] = p.original_url
        response = HTTParty.post('https://api.pinterest.com/v1/pins/', query: opts, headers: { 'Authorization' => "BEARER #{ENV['pinterest_token']}" })
        if response.code == 201
          puts "Exported #{permalink_url(entry)} (#{i + 1}/#{entries.size})"
        else
          puts "Exporting failed at entry ID #{entry.id}: #{response.body}"
        end
      end
    end
  end
end

def permalink_url(entry)
  year, month, day, id, slug = entry.slug_params
  protocol = Rails.configuration.force_ssl ? 'https' : 'http'
  Rails.application.routes.url_helpers.entry_long_url(year, month, day, id, slug, { host: entry.blog.domain, protocol: protocol })
end
