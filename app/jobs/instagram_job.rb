class InstagramJob < BufferJob
  queue_as :default

  def perform(entry)
    text_array = []
    text_array << entry.plain_title
    text_array << entry.plain_body if entry.body.present?
    text_array << custom_hashtags(entry)

    text = text_array.join("\n\n")

    ids = get_profile_ids('instagram')
    media = media_hash(entry.photos.first)
    post_to_buffer(ids, text, media)
  end

 private
 # Checks the entry's tags; if it includes any of the keys in the hashtags.yml
 # as a tag, then it appends the list under that key as additional hashtags
 # for instagram
 def custom_hashtags(entry)
   entry_tags = entry.combined_tags.map { |t| t.slug.gsub(/-/, '') }
   instagram_tags = []
   custom_hashtags = YAML.load_file(Rails.root.join('config/hashtags.yml'))['instagram']
   custom_hashtags.each do |k, v|
     if k == 'all'
       instagram_tags << custom_hashtags[k].sample(3)
     elsif entry_tags.include? k
       instagram_tags << custom_hashtags[k].sample(3)
     end
   end
   instagram_tags.flatten.uniq.sample(rand(8..10)).map { |t| "##{t}"}.join(' ')
 end

 def media_hash(photo)
   image_url = if photo.is_vertical?
     photo.url(w: 1080, h: 1350, fit: 'fill', bg: 'fff', fm: 'jpg')
   elsif photo.is_horizontal?
     photo.url(w: 1080, h: 864, fit: 'fill', bg: 'fff', fm: 'jpg')
   else
     photo.url(w: 1080, fm: 'jpg')
   end

   {
     photo: image_url,
     thumbnail: photo.url(w: 512, fm: 'jpg')
   }
 end
end
