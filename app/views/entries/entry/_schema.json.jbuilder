json.array! entry.photos do |photo|
  json.set! '@context', 'http://schema.org'
  json.set! '@type', 'ImageObject'
  json.set! 'contentUrl', photo.sitemap_url
  json.set! 'creditText', entry.user.name
  json.creator do
    json.set! '@type', 'Person'
    json.name entry.user.name
    json.url about_url
  end
  json.set! 'copyrightNotice', t('blog.copyright')
end
