Resque.redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
Resque.after_fork = Proc.new { ActiveRecord::Base.establish_connection }
