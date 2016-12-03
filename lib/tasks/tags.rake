namespace :tags do
  namespace :update do
    task :equipment => [:environment] do
      Entry.find_each do |e|
        tags = []
        e.photos.each do |p|
          tags << p.formatted_camera
          tags << p.formatted_film if p.film_make.present? && p.film_type.present?
        end
        e.equipment_list.add(tags)
        e.save
      end
    end

    task :locations => [:environment] do
      Entry.find_each do |e|
        ReverseGeocodeJob.perform_later(e) if e.location_list.blank?
      end
    end

    task :objects => [:environment] do
      Entry.find_each do |e|
        ImageAnalysisJob.perform_later(e)
      end
    end
  end

  task :cleanup => [:environment] do
    Entry.find_each do |e|
      e.tag_list.remove(e.equipment_list)
      e.tag_list.remove(e.location_list)
      e.tag_list.remove(e.object_list)
      e.save
    end
  end
end
