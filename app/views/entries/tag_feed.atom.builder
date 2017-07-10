cache "feed/atom/tagged/#{@tag_slug}/page/#{@page}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  xml.instruct!
  xml.feed xmlns: 'http://www.w3.org/2005/Atom' do
    if @page.nil? || @page == 1
      xml.id atom_tag(tag_url(tag: @tag_slug), @photoblog.updated_at)
      xml.title "#{@tags.first.name.titlecase} - #{@photoblog.name}"
      xml.link rel: 'alternate', type: 'text/html', href: tag_url(tag: @tag_slug)
      xml.link rel: 'self', type: 'application/atom+xml', href: tag_feed_url(tag: @tag_slug, format: 'atom')
    else
      xml.id atom_tag(tag_url(tag: @tag_slug, page: @page), @photoblog.updated_at)
      xml.title "#{@tags.first.name.titlecase} - #{@photoblog.name} - Page #{@page}"
      xml.link rel: 'alternate', type: 'text/html', href: tag_url(tag: @tag_slug, page: @page)
      xml.link rel: 'self', type: 'application/atom+xml', href: tag_feed_url(tag: @tag_slug, page: @page, format: 'atom')
    end
    xml.updated @photoblog.updated_at.utc.strftime('%FT%TZ')

    @entries.each do |e|
      cache "feed/atom/entry/#{e.id}/#{e.updated_at.to_i}" do
        xml.entry do
          xml.id atom_tag(e.permalink_url, e.updated_at)
          xml.published e.published_at.utc.strftime('%FT%TZ')
          xml.updated e.updated_at.utc.strftime('%FT%TZ')
          xml.link rel: 'alternate', type: 'text/html', href: e.permalink_url
          xml.title e.plain_title
          body = ''
          e.photos.each do |p|
            body += image_tag p.url(w: 1280), srcset: "#{p.url(w: 1280)} 1x, #{p.url(w: 2560)} 2x", alt: p.caption.blank? ? e.title : p.plain_caption
          end
          body += e.formatted_body unless e.body.blank?
          xml.content body, type: 'html'
          xml.author do |author|
            author.name e.user.name
          end
        end
      end
    end
  end
end
