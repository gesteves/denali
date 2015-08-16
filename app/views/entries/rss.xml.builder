cache "rss/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  xml.instruct!
  xml.feed xmlns: 'http://www.w3.org/2005/Atom' do
    xml.id atom_tag(root_url, @photoblog.updated_at)
    xml.link rel: 'alternate', type: 'text/html', href: root_url
    xml.link rel: 'self', type: 'application/atom+xml', href: rss_url
    xml.title @photoblog.name
    xml.updated @photoblog.updated_at.utc.strftime('%FT%TZ')

    @entries.each do |e|
      cache "entry/rss/#{e.id}/#{e.updated_at.to_i}" do
        xml.entry do
          xml.id atom_tag(permalink_url(e), e.updated_at)
          xml.published e.published_at.utc.strftime('%FT%TZ')
          xml.updated e.updated_at.utc.strftime('%FT%TZ')
          xml.link rel: 'alternate', type: 'text/html', href: permalink_url(e)
          xml.title e.formatted_title
          body = ''
          e.photos.each do |p|
            body += image_tag p.url(1280)
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
