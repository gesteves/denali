namespace :locations do
  namespace :update do
    desc 'Populates tagged entries with a location'
    task :tag => :environment do
      next unless ENV['TAG'].present? && ENV['LOCATION'].present?
      puts "Updating all entries tagged “#{ENV['TAG']}” with location “#{ENV['LOCATION']}”"
      Entry.tagged_with(ENV['TAG']).each do |e|
        e.photos.each do |p|
          p.location = ENV['LOCATION']
          p.save!
        end
      end
    end

    desc 'Populates an entry with a park'
    task :entry => :environment do
      next unless ENV['LOCATION'].present? && ENV['ENTRY_ID'].present?
      puts "Updating entry tagged “#{ENV['ENTRY_ID']}” with location “#{ENV['LOCATION']}”"
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        entry.photos.each do |p|
          p.location = ENV['LOCATION']
          p.save!
        end
      end
    end

    task :national_parks => :environment do
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
            display_name: park['fullName'],
            code: park['parkCode'].downcase,
            designation: park['designation'],
            url: park['url'],
            slug: park['fullName'].parameterize
          )
          puts "Saved #{park['fullName']} (#{park['parkCode']})" if new_park.save
        end
      end
    end

    task :park_display_names => :environment do
      parks = Park.where(display_name: nil)
      parks.find_each do |park|
        park.display_name = park.full_name
        park.save!
        puts "Saved #{park.display_name}"
      end
    end
  end
end
