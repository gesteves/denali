xml.instruct!
xml.urlset xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9' do
  xml.url do
    xml.loc root_url
    xml.lastmod photoblog.updated_at.strftime('%Y-%m-%dT%H:%M:%S%z')
  end
  @entries.each do |e|
    xml.url do
      xml.loc permalink e, { path_only: false }
      xml.lastmod e.updated_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
    end
  end
end
