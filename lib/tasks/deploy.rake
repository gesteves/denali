task :deploy => ['deploy:push', 'deploy:figaro']

namespace :deploy do
  task :migrations => [:push, :off, :figaro, :migrate, :restart, :on]

  task :push do
    puts 'Pushing app to Heroku...'
    system('git push heroku master')
  end

  task :figaro do
    puts 'Syncing configuration values...'
    system('bundle exec figaro heroku:set -e production')
  end

  task :restart do
    puts 'Restarting app servers...'
    system('heroku restart')
  end

  task :migrate do
    puts 'Running database migrations…'
    system('heroku run rake db:migrate')
  end

  task :off do
    puts 'Putting the app into maintenance mode...'
    system('heroku maintenance:on')
  end

  task :on do
    puts 'Taking the app out of maintenance mode...'
    system('heroku maintenance:off')
  end
end
