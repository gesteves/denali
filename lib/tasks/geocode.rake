namespace :geocode do
  desc "Refreshes location info for entries"
  task :refresh => :environment do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        entry.photos.map { |photo| GeocodeJob.perform_later(photo) }
        puts "Geocode jobs queued"
      else
        puts 'That entry wasn\'t found.'
      end
    elsif ENV['COUNT'].present?
      count = ENV['COUNT'].to_i
      entries = Entry.published.limit(count)
      entries.map(&:photos).flatten.map { |photo| GeocodeJob.perform_later(photo) }
      puts "Geocode jobs queued"
    else
      puts 'Please specify `ENTRY_ID` or `COUNT`.'
    end
  end

  desc "Refreshes location info for all entries"
  task :refresh_all => :environment do
    Photo.all.map { |photo| GeocodeJob.perform_later(photo) }
    puts "Geocode jobs queued"
  end
end
