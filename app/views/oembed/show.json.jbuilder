json.type @entry.is_photo? ? 'photo' : 'link'
json.version '1.0'
json.title @entry.plain_title
json.author @entry.user.name
if @entry.is_photo?
  json.url @url
  json.width @width
  json.height @height
end
