namespace :analyze do
  desc 'Runs analyze on photos'
  task :photos => :environment do
    Photo.find_each do |photo|
      PhotoAnalyzeJob.perform_async(photo.id)
    end
  end
end
