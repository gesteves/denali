cache "feed/atom/page/#{@page}/count/#{@count}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  xml.instruct!
  xml.feed xmlns: 'http://www.w3.org/2005/Atom', 'xmlns:webfeeds': 'http://webfeeds.org/rss/1.0' do
    if @page.nil? || @page == 1
      xml.id atom_tag(root_url, @entries.map(&:modified_at).max)
      xml.title @photoblog.name
      xml.link rel: 'alternate', type: 'text/html', href: root_url
      xml.link rel: 'self', type: 'application/atom+xml', href: feed_url(format: 'atom', page: nil)
    else
      xml.id atom_tag(entries_url(page: @page), @entries.map(&:modified_at).max)
      xml.title "#{@photoblog.name} · Page #{@page}"
      xml.link rel: 'alternate', type: 'text/html', href: entries_url(page: @page)
      xml.link rel: 'self', type: 'application/atom+xml', href: feed_url(page: @page, format: 'atom')
    end
    xml.updated @entries.map(&:modified_at).max.utc.strftime('%FT%TZ')
    xml.description @photoblog.plain_description
    xml.tag! 'webfeeds:accentColor', '#BF0222'
    xml.tag! 'webfeeds:wordmark', @photoblog.logo_url(w: 192) if @photoblog.logo.attached?
    xml.tag! 'webfeeds:icon', @photoblog.touch_icon_url(w: 192) if @photoblog.touch_icon.attached?
    xml.tag! 'webfeeds:related', layout: 'card', target: 'browser'

    @entries.each do |e|
      xml.entry do
        xml.id atom_tag(e.permalink_url, e.modified_at)
        xml.published e.published_at.utc.strftime('%FT%TZ')
        xml.updated e.modified_at.utc.strftime('%FT%TZ')
        xml.link rel: 'alternate', type: 'text/html', href: e.permalink_url
        xml.title e.plain_title
        xml.content render(partial: 'feed_entry_body.html.erb', locals: { entry: e }), type: 'html'
        xml.tag! 'webfeeds:featuredImage', url: e.photos.first.url(w: 2560, fm: 'jpg'), type: 'image/jpg', width: 2560, height: e.photos.first.height_from_width(2560) if e.is_photo?
        xml.author do |author|
          author.name e.user.name
        end
      end
    end
  end
end
