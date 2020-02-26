cache @photoblog do
  xml.instruct!
  xml.rss version: '2.0', 'xmlns:atom': 'http://www.w3.org/2005/Atom', 'xmlns:media': 'http://search.yahoo.com/mrss/' do
    xml.channel do
      xml.title @photoblog.name
      xml.link root_url
      xml.description @photoblog.plain_tag_line
      xml.pubDate @entries.map(&:modified_at).max.utc.rfc822
      xml.tag! 'atom:link', href: feed_url(format: 'rss'), rel: 'self', type: 'application/rss+xml'

      @entries.each do |e|
        xml.item do
          xml.guid e.permalink_url, isPermaLink: true
          xml.pubDate e.published_at.utc.rfc822
          xml.link e.permalink_url
          e.photos.each do |photo|
            xml.tag! 'media:content', url: photo.url(w: 1280, fm: 'jpg')
          end
          xml.title e.plain_title
          xml.description render(partial: 'entries/feed/feed_entry_body.html.erb', locals: { entry: e })
        end
      end
    end
  end
end
