namespace :locations do
  desc 'Runs analyze on photos'
  task :update => :environment do
    Entry.find_each do |entry|
      next unless entry.instagram_locations.present?
      puts "Updating entry #{entry.id}; location: #{entry.instagram_location_list}"
      entry.tag_list.add(entry.instagram_location_list)
      entry.instagram_location_list = []
      entry.save!
    end
  end
end
