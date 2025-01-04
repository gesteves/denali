namespace :geocode do
  desc 'Update reverse geocoding for all photos'
  task :all => :environment do
    Photo.find_each do |photo|
      photo.geocode
    end
  end

  desc 'Update reverse geocoding for all photos with missing country'
  task :missing_country => :environment do
    Photo.where(country: nil).where.not(latitude: nil, longitude: nil).find_each do |photo|
      puts "Geocoding photo for entry #{photo.entry.permalink_url}"
      photo.geocode
    end
  end
end
