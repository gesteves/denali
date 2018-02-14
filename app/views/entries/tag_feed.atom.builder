cache "feed/atom/tagged/#{@tag_slug}/page/#{@page}/count/#{@count}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  xml.instruct!
  xml.feed xmlns: 'http://www.w3.org/2005/Atom' do
    if @page.nil? || @page == 1
      xml.id atom_tag(tag_url(tag: @tag_slug), @photoblog.updated_at)
      xml.title "#{@tags.first.name} - #{@photoblog.name}"
      xml.link rel: 'alternate', type: 'text/html', href: tag_url(tag: @tag_slug, page: nil)
      xml.link rel: 'self', type: 'application/atom+xml', href: tag_feed_url(tag: @tag_slug, page: nil, format: 'atom')
    else
      xml.id atom_tag(tag_url(tag: @tag_slug, page: @page), @photoblog.updated_at)
      xml.title "#{@tags.first.name} - #{@photoblog.name} - Page #{@page}"
      xml.link rel: 'alternate', type: 'text/html', href: tag_url(tag: @tag_slug, page: @page)
      xml.link rel: 'self', type: 'application/atom+xml', href: tag_feed_url(tag: @tag_slug, page: @page, format: 'atom')
    end
    xml.updated @photoblog.updated_at.utc.strftime('%FT%TZ')

    @entries.each do |e|
      xml.entry do
        xml.id atom_tag(e.permalink_url, e.updated_at)
        xml.published e.published_at.utc.strftime('%FT%TZ')
        xml.updated e.updated_at.utc.strftime('%FT%TZ')
        xml.link rel: 'alternate', type: 'text/html', href: e.permalink_url
        xml.title e.plain_title
        xml.content render(partial: 'feed_entry_body.html.erb', locals: { entry: e }), type: 'html'
        xml.author do |author|
          author.name e.user.name
        end
      end
    end
  end
end
