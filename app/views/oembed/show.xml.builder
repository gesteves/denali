xml.instruct!
xml.ombed do
  xml.type @entry.is_photo? ? 'photo' : 'link'
  xml.version '1.0'
  xml.title @entry.plain_title
  xml.author_name @entry.user.name
  xml.author_url about_url
  xml.provider_name @entry.blog.name
  xml.provider_url root_url
  if @entry.is_photo?
    xml.thumbnail_url @thumb_url
    xml.thumbnail_width @thumb_width
    xml.thumbnail_height @thumb_height
    xml.url @url
    xml.width @width
    xml.height @height
  end
end
