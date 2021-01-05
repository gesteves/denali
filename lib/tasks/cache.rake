namespace :cache do
  desc 'Clear Rails cache'
  task :clear => :environment do
    Rails.cache.clear
    HerokuRestartWorker.perform_async
    CloudfrontInvalidationWorker.perform_async(['/*'])
  end
end
