namespace :cache do
  desc 'Clear Rails cache'
  task :clear => :environment do
    Rails.cache.clear
    CloudfrontInvalidationWorker.perform_async(['/*'])
  end
end
