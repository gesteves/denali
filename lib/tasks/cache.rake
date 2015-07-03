namespace :cache do
  desc "Clears Rails cache"
  task :clear => :environment do
    puts 'Clearing Rails cache…'
    Rails.cache.clear
    puts 'Rails cache has been cleared.'
  end
end
