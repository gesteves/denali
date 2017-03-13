class InstagramJob < BufferJob
  queue_as :default

  def perform(entry)
    all_tags = entry.combined_tags.map { |t| t.slug.gsub(/-/, '') }

    # Special tags for Fuji
    if entry.equipment_list.include? 'fujifilm'
      all_tags += %w{ fujifeed fujifilmx_us fujilove fujifilm_xseries }
    end

    text_array = []
    text_array << entry.plain_title
    text_array << entry.plain_body if entry.body.present?
    text_array << all_tags.sort.map { |t| "##{t}"}.join(' ')

    text = text_array.join("\n\n")
    image_url = if entry.photos.first.is_vertical?
      entry.photos.first.url(w: 1080, h: 1350, fit: 'fill', bg: 'fff')
    else
      entry.photos.first.url(w: 1080)
    end
    thumbnail_url = entry.photos.first.url(w: 512)

    post_to_buffer('instagram', text, image_url, thumbnail_url)
  end
end
