namespace :cache do
  desc 'Clear Rails cache'
  task :clear => :environment do
    Rails.cache.clear
    HerokuConfigWorker.perform_async({ CACHE_VERSION: Time.now.to_i.to_s })
    CloudfrontInvalidationWorker.perform_async(['/*'])
  end
end
