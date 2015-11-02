namespace :tumblr do
  desc 'Import all posts to Tumblr'
  task :export => [:environment] do
    limit = ENV['ENTRY_COUNT'] || 125
    if ENV['ENTRY_ID'].present?
      entries = Entry.published('published_at DESC').where('id = ?', ENV['ENTRY_ID']).limit(limit)
    elsif ENV['NEWEST_ENTRY_ID'].present? && ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.published('published_at DESC').where('id <= ? AND id >= ?', ENV['NEWEST_ENTRY_ID'], ENV['OLDEST_ENTRY_ID']).photo_entries.limit(limit)
    elsif ENV['NEWEST_ENTRY_ID'].present?
      entries = Entry.published('published_at DESC').where('id <= ?', ENV['NEWEST_ENTRY_ID']).photo_entries.limit(limit)
    elsif ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.published('published_at DESC').where('id >= ?', ENV['OLDEST_ENTRY_ID']).photo_entries.limit(limit)
    else
      entries = Entry.published('published_at DESC').photo_entries.limit(limit)
    end
    entries.each_with_index do |entry, i|
      tumblr = Tumblr::Client.new({
        consumer_key: ENV['tumblr_consumer_key'],
        consumer_secret: ENV['tumblr_consumer_secret'],
        oauth_token: ENV['tumblr_access_token'],
        oauth_token_secret: ENV['tumblr_access_token_secret']
      })
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
end

def permalink_url(entry)
  year, month, day, id, slug = entry.slug_params
  protocol = Rails.configuration.force_ssl ? 'https' : 'http'
  Rails.application.routes.url_helpers.entry_long_url(year, month, day, id, slug, { host: entry.blog.domain, protocol: protocol })
end
