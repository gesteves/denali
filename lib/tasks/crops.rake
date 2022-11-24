namespace :crops do
  desc 'Update crops for all photos'
  task :update_all => :environment do
    Crop.find_each do |crop|
      case crop.name
      when 'square'
        crop.aspect_ratio = '1:1'
      when 'facebook'
        crop.aspect_ratio = '1200:630'
      end
      puts "Updating crop #{crop.id} #{crop.name} to #{crop.aspect_ratio}"
      crop.save!
    end
  end
end
