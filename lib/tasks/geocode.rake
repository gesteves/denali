namespace :geocode do
  desc 'Update reverse geocoding for all photos'
  task :all => :environment do
    Photo.find_each do |photo|
      photo.geocode
    end
  end

  desc 'Rename Mexico City to Ciudad de México'
  task :translate_mexico_city => :environment do
    Photo.where(locality: 'Mexico City').update_all(locality: 'Ciudad de México')
  end
end
