namespace :locations do
  task :update => :environment do
    if ENV['TAG'].present?
      Entry.tagged_with(ENV['TAG'], any: true).each do |entry|
        puts "Updating entry #{entry.id}"
        entry.instagram_location_list = ENV['TAG']
        entry.save!
      end
    end
  end
end
