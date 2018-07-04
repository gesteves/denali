cache "sitemap/index/#{@photoblog.cache_key}" do
  xml.instruct!
  xml.sitemapindex xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9' do
    @pages.times do |page|
      xml.sitemap do
        xml.loc sitemap_url(page: page + 1)
        xml.lastmod @photoblog.entries.published.page(page + 1).per(@entries_per_sitemap).pluck(:modified_at).max.strftime('%Y-%m-%dT%H:%M:%S%:z')
      end
    end
  end
end
