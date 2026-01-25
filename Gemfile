source 'https://rubygems.org'
ruby '3.4.7'

gem 'rails', '8.1.2'
gem 'pg', '~> 1.6'
gem 'puma'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Auth
gem 'omniauth-google-oauth2'
gem 'omniauth-rails_csrf_protection'

# AWS
gem 'aws-sdk-cloudfront', '~> 1'
gem 'aws-sdk-s3', '~> 1'

# Front-end things
gem 'dartsass-rails'
gem 'autoprefixer-rails'
gem 'uglifier', '>= 1.3.0'
gem 'jsbundling-rails'
gem 'turbolinks', '~> 5.2.1'
gem "sprockets-rails"

# Images
gem 'ruby-thumbor'
gem 'blurhash', git: 'https://github.com/gesteves/blurhash', branch: 'master'

# Misc
gem 'jbuilder', '~> 2.14'
gem 'sdoc', '~> 2.6', group: :doc
gem 'acts_as_list'
gem 'redcarpet'
gem 'sanitize'
gem 'exifr', require: nil
gem 'acts-as-taggable-on'
gem 'httparty', '~> 0.24'
gem 'kaminari'
gem 'figaro'
gem 'oauth'
gem "image_processing", "~> 1.14"
gem 'rack-brotli'
gem 'htmlentities'
gem 'public_suffix'
gem 'web-push'

# Monitoring
gem 'bugsnag'

# Caching
gem 'redis'

# Background Jobs
gem 'connection_pool', '~> 2.5'  # Pin to 2.x until Sidekiq/redis-client support 3.0
gem 'sidekiq'
gem 'sidekiq-scheduler'

# Social Networks
gem 'flickraw', git: 'https://github.com/gesteves/flickraw.git', branch: 'update-upload-url'

# Search
gem 'elasticsearch-model', '~> 8.0'
gem 'elasticsearch-rails', '~> 8.0'

gem 'graphql'

group :production do
  gem 'lograge'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.11'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.1.0'
end

group :development, :test do
  gem 'scss-lint'
  gem 'byebug'
  gem 'brakeman', require: nil
end

group :test do
  gem 'rspec-rails', '~> 7.0'
  gem 'factory_bot_rails'
  gem 'shoulda-matchers'
  gem 'webmock'
  gem 'vcr'
  gem 'rspec-sidekiq'
  gem 'faker'
  gem 'simplecov', require: false
  gem 'mock_redis'
  gem 'rails-controller-testing'
end

gem "dockerfile-rails", ">= 1.7", :group => :development
