namespace :tumblr do
  desc 'Import all posts to Tumblr'
  task :export => [:environment] do
    entries = Entry.published('published_at ASC').photo_entries
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
      else
        puts "Exporting #{opts[:link]} failed (#{i + 1}/#{entries.size})"
      end
      sleep 1
    end
  end
end

def permalink_url(entry)
  year, month, day, id, slug = entry.slug_params
  protocol = Rails.configuration.force_ssl ? 'https' : 'http'
  Rails.application.routes.url_helpers.entry_long_url(year, month, day, id, slug, { host: entry.blog.domain, protocol: protocol })
end
