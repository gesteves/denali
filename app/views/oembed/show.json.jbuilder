json.type @entry.is_photo? ? 'photo' : 'link'
json.version '1.0'
json.title @entry.plain_title
json.author @entry.user.name
json.author_url root_url
json.provider @entry.blog.name
json.provider_url root_url
if @entry.is_photo?
  json.thumbnail_url @thumb_url
  json.thumbnail_width @thumb_width
  json.thumbnail_height @thumb_height
  json.url @url
  json.width @width
  json.height @height
end
