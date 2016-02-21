cache "sitemap/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  xml.instruct!
  xml.urlset xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9' do
    xml.url do
      xml.loc root_url
      xml.lastmod @photoblog.updated_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
    end
    @entries.each do |e|
      xml.url do
        xml.loc e.permalink_url
        xml.lastmod e.updated_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
      end
    end
  end
end
