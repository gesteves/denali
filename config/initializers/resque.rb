if Rails.env.test?
  Resque.redis = MockRedis.new
else
  Resque.redis = Redis.new(url: ENV['HEROKU_REDIS_ROSE_URL'] || 'redis://localhost:6379')
end
Resque.after_fork = Proc.new { ActiveRecord::Base.establish_connection }
