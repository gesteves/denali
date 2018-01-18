class InstagramJob < BufferJob
  queue_as :default

  def perform(entry)
    text_array = []
    text_array << entry.plain_title
    text_array << entry.plain_body if entry.body.present?
    text_array << custom_hashtags(entry)

    text = text_array.join("\n\n")
    image_url = if entry.photos.first.is_vertical?
      entry.photos.first.url(w: 1080, h: 1350, fit: 'fill', bg: 'fff', fm: 'jpg')
    elsif entry.photos.first.is_horizontal?
      entry.photos.first.url(w: 1080, h: 864, fit: 'fill', bg: 'fff', fm: 'jpg')
    else
      entry.photos.first.url(w: 1080, fm: 'jpg')
    end
    thumbnail_url = entry.photos.first.url(w: 512, fm: 'jpg')

    ids = get_profile_ids('instagram')
    post_to_buffer(ids, text, image_url, thumbnail_url)
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
       instagram_tags += custom_hashtags[k]
     elsif entry_tags.include? k
       instagram_tags += custom_hashtags[k]
     end
   end
   tags = instagram_tags.sort + entry_tags.sort
   tags.sample(rand(5..10)).map { |t| "##{t}"}.join(' ')
 end
end
