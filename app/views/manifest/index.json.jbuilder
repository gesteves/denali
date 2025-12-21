json.set! 'name', @photoblog.name
json.set! 'start_url', root_url
json.set! 'display', 'standalone'
json.set! 'description', t('blog.tag_line')
json.icons @icons do |icon|
  json.set! 'src', icon[:src]
  json.set! 'sizes', icon[:sizes]
  json.set! 'type', 'image/png'
end
