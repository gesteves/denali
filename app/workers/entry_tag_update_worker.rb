class EntryTagUpdateWorker < ApplicationWorker

  def perform(entry_id)
    entry = Entry.find(entry_id)
    equipment_tags = []
    location_tags = []
    style_tags = []
    entry.photos.each do |p|
      equipment_tags << [p.camera&.make, p.camera&.display_name, p.film&.display_name]
      style_tags << (p.color? ? 'Color' : 'Black and White') unless p.color?.nil?
      style_tags << 'Film' if p.film.present?
      style_tags << 'Mobile' if p.camera&.is_phone?
      location_tags  << [p.country, p.locality, p.sublocality, p.neighborhood, p.administrative_area] if entry.show_in_map?
    end
    equipment_tags = equipment_tags.flatten.uniq.reject(&:blank?)
    location_tags = location_tags.flatten.uniq.reject(&:blank?)
    style_tags = style_tags.flatten.uniq.reject(&:blank?)
    entry.equipment_list = equipment_tags
    entry.location_list = location_tags
    entry.style_list = style_tags
    entry.tag_list.remove(equipment_tags + location_tags + ['Color', 'Black and White', 'Film'])
    entry.save!
  end
end
