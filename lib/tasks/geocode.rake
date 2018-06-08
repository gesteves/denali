namespace :geocode do
  desc "Refreshes location info for entries"
  task :refresh => :environment do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        GeocodeJob.perform_later(entry)
        puts "Geocode job queued"
      else
        puts 'That entry wasn\'t found.'
      end
    elsif ENV['COUNT'].present?
      count = ENV['COUNT'].to_i
      entries = Entry.published.limit(count)
      entries.map { |entry| GeocodeJob.perform_later(entry) }
      puts "Geocode jobs queued"
    else
      puts 'Please specify `ENTRY_ID` or `COUNT`.'
    end
  end

  desc "Refreshes location info for all entries"
  task :refresh_all => :environment do
    Entry.map { |entry| GeocodeJob.perform_later(entry) }
    puts "Geocode jobs queued"
  end
end
