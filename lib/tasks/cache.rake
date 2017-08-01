namescape :cache do
  desc 'Clear Rails cache'
  task :clear => :environment do
    Rails.cache.clear
  end
end
