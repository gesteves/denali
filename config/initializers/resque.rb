if Rails.env.test?
  Resque.redis = MockRedis.new
else
  Resque.redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
end
Resque.after_fork = Proc.new { ActiveRecord::Base.establish_connection }
