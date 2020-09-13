namespace :analyze do
  desc 'Runs analyze on photos'
  task :photos => :environment do
    Photos.find_each do |photo|
      if photo.image.metadata[:width].blank? || photo.image.metadata[:height].blank?
        puts "Analyzing photo ID #{photo.id}"
        photo.image.analyze_later
      end
    end
  end
end
