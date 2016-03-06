cache "entries/tagged/atom/#{@tag_slug}/page/#{@page}/count/#{@count}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  xml.instruct!
  xml.feed xmlns: 'http://www.w3.org/2005/Atom' do
    if @page.nil? || @page == 1
      xml.id atom_tag(tag_url(tag: @tag_slug), @photoblog.updated_at)
      xml.title "#{@photoblog.name} - Entries tagged “#{@tags.first.name}”"
      xml.link rel: 'alternate', type: 'text/html', href: tag_url(tag: @tag_slug)
    else
      xml.id atom_tag(tag_url(tag: @tag_slug, page: @page), @photoblog.updated_at)
      xml.title "#{@photoblog.name} - Entries tagged “#{@tags.first.name}” - Page #{@page}"
      xml.link rel: 'alternate', type: 'text/html', href: tag_url(tag: @tag_slug, page: @page)
    end
    xml.link rel: 'self', type: 'application/atom+xml', href: tag_url(page: @page, format: 'atom', tag: @tag_slug)
    xml.updated @photoblog.updated_at.utc.strftime('%FT%TZ')

    @entries.each do |e|
      cache "entry/atom/#{e.id}/#{e.updated_at.to_i}" do
        xml.entry do
          xml.id atom_tag(e.permalink_url, e.updated_at)
          xml.published e.published_at.utc.strftime('%FT%TZ')
          xml.updated e.updated_at.utc.strftime('%FT%TZ')
          xml.link rel: 'alternate', type: 'text/html', href: e.permalink_url
          xml.title e.plain_title
          body = ''
          e.photos.each do |p|
            body += image_tag p.url(w: 1280)
            body += p.formatted_caption unless p.caption.blank?
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
