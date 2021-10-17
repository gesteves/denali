namespace :parks do
  desc 'Populates tagged entries with a park'
  task :tag => :environment do
    next unless ENV['TAG'].present? && ENV['PARK_CODE'].present?
    puts "Updating all entries tagged “#{ENV['TAG']}” with park code #{ENV['PARK_CODE']}"
    Entry.tagged_with(ENV['TAG']).each do |e|
      e.photos.each do |p|
        p.park_code = ENV['PARK_CODE'].downcase
        p.save!
      end
    end
  end

  desc 'Populates an entry with a park'
  task :entry => :environment do
    next unless ENV['PARK_CODE'].present? && ENV['ENTRY_ID'].present?
    puts "Updating entry tagged “#{ENV['ENTRY_ID']}” with park code #{ENV['PARK_CODE']}"
    entry = Entry.find(ENV['ENTRY_ID'])
    if entry.present?
      entry.photos.each do |p|
        p.park_code = ENV['PARK_CODE'].downcase
        p.save!
      end
    end
  end
end
