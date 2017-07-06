cache "sitemap/index/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  xml.instruct!
  xml.sitemapindex xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9' do
    @pages.times do |page|
      xml.sitemap do
        xml.loc sitemap_url(page: page + 1)
        xml.lastmod @photoblog.updated_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
      end
    end
  end
end
