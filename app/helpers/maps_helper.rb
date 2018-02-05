module MapsHelper
  def tooltip_content(photo, entry)
    content_tag :div, class: 'entry-list__item entry-list__item--map' do
      content_tag :div, class: 'entry-list__wrapper' do
        link_to entry.permalink_url, { class: 'entry-list__link entry-list__link--photo', target: 'blank', style: "background-color:#{photo.dominant_color};" } do
          content_tag :figure, class: 'entry-list__photo' do
            img = responsive_image_tag(photo, 'map', { class: 'entry-list__image' })
            caption = content_tag :figcaption, class: 'entry-list__photo-caption' do
              title = content_tag :p, class: 'entry-list__photo-title' do
                raw truncate(entry.plain_title, length: 80, separator: ' ', omission: '…', escape: false)
              end
              pubdate = content_tag :p, class: 'entry-list__photo-meta' do
                "Published on #{entry.published_at.strftime('%B %-d, %Y')}"
              end
              title + pubdate
            end
            img + caption
          end
        end
      end
    end
  end
end
