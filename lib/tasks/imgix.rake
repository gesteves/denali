namespace :imgix do
  desc 'Purge all images from imgix'
  task :purge_all => :environment do
    Photo.find_each do |photo|
      ImgixPurgeWorker.perform_async(photo.id)
    end
  end
end
