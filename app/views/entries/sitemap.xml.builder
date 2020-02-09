cache [@photoblog, @page] do
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
            xml.image :caption, p.alt_text
            xml.image :title, e.plain_title
            xml.image :geo_location, p.location if e.show_in_map? && p.location.present?
          end
        end
      end
    end
  end
end
