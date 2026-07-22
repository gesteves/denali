# The vocabulary of Cache-Tag values attached to cacheable responses.
#
# Controllers attach tags with ApplicationController#set_cache_tags; models purge
# them through CachePurgeJob when the content behind them changes. Both sides
# have to agree on the spelling, so they name it here rather than inline.
#
# Cloudflare consumes the Cache-Tag header and strips it before the response
# reaches the client. Tags must be printable ASCII with no spaces.
module CacheTags
  # Anything that renders a list, feed or sitemap of entries, and so changes
  # whenever any entry is published, edited or deleted.
  ENTRIES = 'entries'

  # Site chrome driven by Blog settings: the about page, manifest, robots.txt
  # and the service worker.
  BLOG = 'blog'

  # A single entry's permalink and its oembed representation.
  def self.entry(entry_id)
    "entry-#{entry_id}"
  end

  # A tag's archive page and feed.
  def self.tag(slug)
    "tag-#{slug.to_s.parameterize}"
  end
end
