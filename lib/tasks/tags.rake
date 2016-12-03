namespace :tags do
  namespace :update do
    task :equipment => [:environment] do
      Entry.find_each do |e|
        tags = []
        e.photos.each do |p|
          tags << p.formatted_camera
          tags << p.formatted_film if p.film_make.present? && p.film_type.present?
        end
        puts "Adding #{tags.to_s} to entry ##{e.id}"
        e.equipment_list.add(tags)
        e.save
      end
    end
  end
end
