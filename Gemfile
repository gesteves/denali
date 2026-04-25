source 'https://rubygems.org'
ruby '4.0.3'

gem 'rails', '8.1.3'
gem 'pg', '~> 1.6'
gem 'puma'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Auth
gem 'omniauth-google-oauth2'
gem 'omniauth-rails_csrf_protection'

# AWS
gem 'aws-sdk-s3', '~> 1'

# Front-end things
gem 'propshaft'
gem 'dartsass-rails'
gem 'jsbundling-rails'
gem 'turbo-rails'

# Images
gem 'ruby-thumbor'
gem 'blurhash', git: 'https://github.com/gesteves/blurhash', branch: 'master'
gem 'mini_magick'

# Misc
gem 'jbuilder', '~> 2.14'
gem 'acts_as_list'
gem 'redcarpet'
gem 'sanitize'
gem 'exifr', require: nil
gem 'acts-as-taggable-on'
gem 'httparty', '~> 0.24'
gem 'kaminari'
gem 'rack-brotli'
gem 'htmlentities'
gem 'web-push'

# Monitoring
gem 'bugsnag'

# Caching
gem 'redis'

# Background Jobs
gem 'connection_pool', '~> 3.0'  # Pin to 2.x until Sidekiq/redis-client support 3.0
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
end

group :development, :test do
  gem 'debug', require: nil
  gem 'brakeman', require: nil
  gem 'bullet'
end

group :test do
  gem 'rspec-rails', '~> 8.0'
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
