module MapsHelper
  def tooltip_content(photo, entry)
    content_tag :div, class: 'entry-list__item entry-list__item--map' do
      link_to permalink_url(entry), { class: 'entry-list__link entry-list__link--photo' } do
        content_tag :figure, class: 'entry-list__photo' do
          img = responsive_image_tag(photo, 'map', { class: 'entry-list__image' })
          caption = content_tag :figcaption, class: 'entry-list__photo-caption' do
            content_tag :p, class: 'entry-list__photo-title' do
              entry.formatted_title
            end
          end
          img + caption
        end
      end
    end
  end
end
