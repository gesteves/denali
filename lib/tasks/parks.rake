namespace :parks do
  desc 'Populates tagged entries with a park'
  task :tag => :environment do
    next unless ENV['TAG'].present? && ENV['PARK_CODE'].present?
    puts "Updating all entries tagged “#{ENV['TAG']}” with park code #{ENV['PARK_CODE']}"
    Entry.tagged_with(ENV['TAG']).each do |e|
      e.photos.each do |p|
        p.location = ENV['PARK_CODE'].downcase
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
        p.location = ENV['PARK_CODE'].downcase
        p.save!
      end
    end
  end

  task :populate => :environment do
    next unless ENV['nps_api_key'].present?

    url = "https://developer.nps.gov/api/v1/parks?limit=1000&api_key=#{ENV['nps_api_key']}"
    response = HTTParty.get(url)
    next if response.code >= 400

    parks = JSON.parse(response.body)['data']
    parks.each do |park|
      p = Park.find_by_code(park['parkCode'])
      if p.present?
        p.update(
          full_name: park['fullName'],
          short_name: park['name'],
          designation: park['designation'],
          url: park['url'],
          slug: park['fullName'].parameterize
        )
        puts "Updated #{park['fullName']} (#{park['parkCode']})"
      else
        new_park = Park.new(
          full_name: park['fullName'],
          short_name: park['name'],
          code: park['parkCode'].downcase,
          designation: park['designation'],
          url: park['url'],
          slug: park['fullName'].parameterize
        )
        puts "Saved #{park['fullName']} (#{park['parkCode']})" if new_park.save
      end
    end
  end
end
