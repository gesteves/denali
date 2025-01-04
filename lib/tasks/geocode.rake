namespace :geocode do
  desc 'Update reverse geocoding for all photos'
  task :all => :environment do
    Photo.find_each do |photo|
      photo.geocode
    end
  end

  desc 'Rename Ciudad de México to Mexico City'
  task :translate_mexico_city => :environment do
    Photo.where(locality: 'Ciudad de México').update_all(locality: 'Mexico City')
  end
end
