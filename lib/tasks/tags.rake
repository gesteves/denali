namespace :tags do
  desc "Updates tags"
  task :update => :environment do
    entries = Entry.tagged_with('National Elk Refuge')
    puts "Found #{entries.size} entries tagged with “National Elk Refuge”."
    entries.each do |entry|
      puts "Updating entry: #{entry.permalink_url}"
      if entry.instagram_locations.blank?
         entry.instagram_location_list.add('National Elk Refuge')
         entry.save!
      end
      entry.update_location_tags
    end
  end
end
