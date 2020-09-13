namespace :analyze do
  desc 'Runs analyze on photos'
  task :photos => :environment do
    Photo.find_each do |photo|
      if photo.image.metadata[:width].blank? || photo.image.metadata[:height].blank?
        PhotoAnalyzeWorker.perform_async(photo.id)
      end
    end
  end
end
