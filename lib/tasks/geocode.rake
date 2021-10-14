namespace :geocode do
  desc 'Update reverse geocoding for all photos'
  task :all => :environment do
    Photo.find_each do |photo|
      photo.geocode
    end
  end
end
