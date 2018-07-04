cache "sitemap/#{@page}/#{@photoblog.cache_key}" do
  xml.instruct!
  xml.urlset xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9',
            'xmlns:image': 'http://www.google.com/schemas/sitemap-image/1.1' do
    @entries.each do |e|
      xml.url do
        xml.loc e.permalink_url
        xml.lastmod e.modified_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
        e.photos.each do |p|
          xml.image :image do
            xml.image :loc, p.url(w: 1200)
            xml.image :caption, p.plain_caption
            xml.image :title, e.plain_title
            xml.image :geo_location, p.long_address if e.show_in_map? && p.has_location?
          end
        end
      end
    end
  end
end
