namespace :tags do
  desc "Updates tags"
  task :update => :environment do
    entries = Entry.tagged_with(['National Parks', 'National Monuments'], any: true)
    puts "Found #{entries.size} entries tagged with “National Parks” or “National Monuments”."
    entries.each do |entry|
      puts "Updating entry: #{entry.permalink_url}"
      if entry.instagram_locations.blank?
        location = entry.tag_list.find { |t| t.match? /\snational (park|monument)/i }
        if location.blank?
          puts "    No location found."
        else
          entry.instagram_location_list.add(location)
          entry.save!
          puts "    Added location: “#{location}”."
        end
      end
      entry.update_location_tags
      if entry.tag_list.include?('Wildlife') && entry.title.match?(/moose/i)
        entry.tag_list.add('Moose')
        entry.save!
        puts "    Added tag: “Moose”."
      end
    end
  end
end
