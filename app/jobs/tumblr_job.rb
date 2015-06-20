require 'open-uri'
class TumblrJob < ActiveJob::Base
  include Addressable

  queue_as :default

  def perform(entry)
    tumblr = Tumblr::Client.new({
      consumer_key: ENV['tumblr_consumer_key'],
      consumer_secret: ENV['tumblr_consumer_secret'],
      oauth_token: ENV['tumblr_access_token'],
      oauth_token_secret: ENV['tumblr_access_token_secret']
    })
    if entry.is_photo?
      photos = []
      entry.photos.each do |p|
        photos << p.original_url
      end
      tumblr.photo(ENV['tumblr_domain'], {
        tags: entry.tag_list.join(', '),
        format: 'markdown',
        slug: entry.slug,
        caption: "#{entry.title}\n\n#{entry.body}",
        state: 'draft',
        link: permalink_url(entry),
        source: photos
      })
    else
      tumblr.text(ENV['tumblr_domain'], {
        tags: entry.tag_list.join(', '),
        format: 'markdown',
        slug: entry.slug,
        title: entry.formatted_title,
        body: entry.body,
        state: 'draft'
      })
    end
  end
end
