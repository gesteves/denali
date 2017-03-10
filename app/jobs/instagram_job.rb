class InstagramJob < BufferJob
  queue_as :default

  def perform(entry)
    all_tags = entry.combined_tags.sort_by { |t| t.name }.map { |t| "##{t.slug.gsub(/-/, '')}" }
    all_tags += ENV['instagram_tags'].split(/,\s*/).map { |t| "##{t}" } if ENV['instagram_tags'].present?

    text_array = []
    text_array << entry.plain_title
    text_array << entry.plain_body if entry.body.present?
    text_array << all_tags.join(' ')

    text = text_array.join("\n\n")

    media = {
      thumbnail: entry.photos.first.url(w: 512)
    }

    media[:picture] = if entry.photos.first.is_vertical?
      entry.photos.first.url(w: 1080, h: 1350, fit: 'fill', bg: 'fff')
    elsif entry.photos.first.is_horizontal?
      entry.photos.first.url(w: 1080, h: 864, fit: 'fill', bg: 'fff')
    elsif entry.photos.first.is_square?
      entry.photos.first.url(w: 1080)
    end

    post_to_buffer('instagram', text, media)
  end
end
