class TumblrJob < EntryJob

  queue_as :default

  def perform(entry)
    tumblr = Tumblr::Client.new({
      consumer_key: ENV['tumblr_consumer_key'],
      consumer_secret: ENV['tumblr_consumer_secret'],
      oauth_token: ENV['tumblr_access_token'],
      oauth_token_secret: ENV['tumblr_access_token_secret']
    })
    opts = {
      tags: entry.tag_list.join(', '),
      slug: entry.slug,
      state: 'draft'
    }
    if entry.is_photo?
      opts.merge!({
        caption: entry.formatted_content,
        link: permalink_url(entry),
        source: entry.photos.map{ |p| p.original_url }
      })
      tumblr.photo(ENV['tumblr_domain'], opts)
    else
      opts.merge!({
        title: entry.formatted_title,
        body: entry.formatted_body
      })
      tumblr.text(ENV['tumblr_domain'], opts)
    end
  end
end
