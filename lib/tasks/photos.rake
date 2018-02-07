namespace :photos do
  task :geocode => [:environment] do
    Photo.find_each do |p|
      puts "Updating geocoding data for photo ##{p.id}"
      p.geocode
    end
  end
  task :palette => [:environment] do
    Photo.find_each do |p|
      puts "Updating palette data for photo ##{p.id}"
      p.update_palette
    end
  end
  task :annotate => [:environment] do
    Photo.find_each do |p|
      puts "Updating annotation data for photo ##{p.id}"
      p.annotate
    end
  end
end
