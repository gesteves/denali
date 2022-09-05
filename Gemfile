source 'https://rubygems.org'
ruby '3.1.2'

gem 'rails', '7.0.3.1'
gem 'pg', '~> 1.4'
gem 'puma'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Auth
gem 'omniauth-google-oauth2'

# AWS
gem 'aws-sdk-cloudfront', '~> 1'
gem 'aws-sdk-s3', '~> 1'

# Front-end things
gem 'sass-rails', '~> 6.0'
gem 'autoprefixer-rails'
gem 'imgix'
gem 'uglifier', '>= 1.3.0'
gem 'webpacker'
gem 'turbolinks', '~> 5.2.1'
gem "sprockets-rails"

# Misc
gem 'jbuilder', '~> 2.11'
gem 'sdoc', '~> 2.4', group: :doc
gem 'acts_as_list'
gem 'redcarpet'
gem 'sanitize'
gem 'exifr', require: nil
gem 'acts-as-taggable-on', '~> 9.0'
gem 'httparty'
gem 'kaminari'
gem 'figaro'
gem 'oauth'
gem 'rack-attack'
gem "image_processing", "~> 1.12"
gem 'rack-brotli'
gem 'typhoeus'
gem 'htmlentities'

# Monitoring
gem 'bugsnag'

# Caching
gem 'redis'
gem 'hiredis'

# Background Jobs
gem 'sidekiq'

# Social Networks
gem 'flickraw', git: 'https://github.com/gesteves/flickraw.git', branch: 'update-upload-url'

# Search
gem 'elasticsearch-model', '~> 5.0'
gem 'elasticsearch-rails', '~> 6.1'

gem 'graphql'

group :production do
  gem 'lograge'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.8'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :development, :test do
  gem 'scss-lint'
  gem 'byebug'
  gem 'brakeman', require: nil
end

group :test do
  gem 'mock_redis'
  gem 'rails-controller-testing'
end
