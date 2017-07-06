xml.instruct!
xml.urlset xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9',
          'xmlns:image': 'http://www.google.com/schemas/sitemap-image/1.1' do
  xml.url do
    xml.loc root_url
    xml.lastmod @photoblog.updated_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
  end
  @entries.each do |e|
    xml.url do
      xml.loc e.permalink_url
      xml.lastmod e.updated_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
      e.photos.each do |p|
        xml.image :image do
          xml.image :loc, p.url(w: 1440)
          xml.image :caption, p.plain_caption
          xml.image :title, e.plain_title
          xml.image :geo_location, e.location_list if e.show_in_map? && p.latitude.present? && p.longitude.present? && e.location_list.present?
        end
      end
    end
  end
end
