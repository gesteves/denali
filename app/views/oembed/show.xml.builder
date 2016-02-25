xml.instruct!
xml.ombed do
  xml.type @entry.is_photo? ? 'photo' : 'link'
  xml.version '1.0'
  xml.title @entry.plain_title
  xml.author @entry.user.name
  if @entry.is_photo?
    xml.url @url
    xml.width @width
    xml.height @height
  end
end
