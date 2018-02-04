namespace :tags do
  task :cleanup => [:environment] do
    Entry.find_each do |e|
      e.tag_list.remove(e.equipment_list)
      e.tag_list.remove(e.location_list)
      e.save
    end
  end
end
