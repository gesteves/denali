namespace :blurhash do
  desc 'Generate blurhashes for all photos'
  task :photos => :environment do
    Photo.find_each do |photo|
      BlurhashWorker.perform_async(photo.id)
    end
  end
end
