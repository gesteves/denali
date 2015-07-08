task :deploy => ['deploy:push', 'deploy:figaro']

namespace :deploy do
  task :migrations => [:push, :off, :figaro, :migrate, :restart, :on]

  task :push do
    puts 'Pushing app to Heroku...'
    puts `git push heroku master`
  end

  task :figaro do
    puts 'Syncing configuration values...'
    puts `bundle exec figaro heroku:set -e production`
  end

  task :restart do
    puts 'Restarting app servers...'
    puts `heroku restart`
  end

  task :migrate do
    puts 'Running database migrations…'
    puts `heroku run rake db:migrate`
  end

  task :off do
    puts 'Putting the app into maintenance mode...'
    puts `heroku maintenance:on`
  end

  task :on do
    puts 'Taking the app out of maintenance mode...'
    puts `heroku maintenance:off`
  end
end
