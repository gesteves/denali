cache "entries/atom/page/#{@page}/count/#{@count}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  xml.instruct!
  xml.feed xmlns: 'http://www.w3.org/2005/Atom' do
    xml.id atom_tag(root_url, @photoblog.updated_at)
    xml.link rel: 'alternate', type: 'text/html', href: root_url
    xml.link rel: 'self', type: 'application/atom+xml', href: entries_url(page: @page, format: 'atom')
    xml.title @photoblog.name
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
            body += image_tag p.url(width: 2732)
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
