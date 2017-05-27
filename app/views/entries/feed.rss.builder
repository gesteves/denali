cache "feed/rss/page/#{@page}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  xml.instruct!
  xml.rss version: '2.0',
          'xmlns:atom': 'http://www.w3.org/2005/Atom',
          'xmlns:dc': 'http://purl.org/dc/elements/1.1/',
          'xmlns:media': 'http://search.yahoo.com/mrss/',
          'xmlns:content': 'http://purl.org/rss/1.0/modules/content/',
          'xmlns:georss': 'http://www.georss.org/georss' do
    xml.channel do
      if @page.nil? || @page == 1
        xml.title @photoblog.name
        xml.link root_url
        xml.description @photoblog.plain_description
        xml.tag! 'atom:link', rel: 'self', type: 'application/rss+xml', href: feed_url(format: 'rss')
      else
        xml.title "#{@photoblog.name} &middot; Page #{@page}"
        xml.link entries_url(page: @page)
        xml.description @photoblog.plain_description
        xml.tag! 'atom:link', rel: 'self', type: 'application/rss+xml', href: feed_url(format: 'rss', page: @page)
      end
      xml.language 'en-us'
      @entries.each do |e|
        cache "feed/rss/entry/#{e.id}/#{e.updated_at.to_i}" do
          xml.item do
            xml.title e.plain_title
            xml.link e.permalink_url
            xml.guid e.permalink_url
            xml.pubDate e.updated_at.to_formatted_s(:rfc822)
            xml.tag! 'dc:creator', e.user.name
            if e.show_in_map? && e.photos.first.latitude.present? && e.photos.first.longitude.present?
              xml.tag! 'georss:point', "#{e.photos.first.latitude} #{e.photos.first.longitude}"
            end
            if e.body.present?
              xml.description e.plain_body
              xml.tag! 'content:encoded' do
                xml.cdata! e.formatted_body
              end
            elsif  e.photos.first.caption.present?
              xml.description e.photos.first.plain_caption
            end
            e.tags.each do |tag|
              xml.category tag.name
            end
            e.photos.each do |photo|
              xml.tag! 'media:group' do
                get_rss_widths(photo, 'entry').each do |width|
                  xml.tag! 'media:content', type: 'image/jpg', medium: 'image', width: width, height: photo.height_from_width(width), url: photo.url(w: width, fm: 'jpg') do
                    xml.tag! 'media:description', type: 'plain' do
                       xml.text! photo.plain_caption
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
