source 'https://rubygems.org'
ruby '2.5.1'

gem 'rails', '5.2.2'
gem 'pg', '~> 0.21'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

# Auth
gem 'omniauth-google-oauth2'

# AWS
gem 'aws-sdk-cloudfront', '~> 1'
gem 'aws-sdk-s3', '~> 1'
gem 'aws-sdk-rekognition', '~> 1'

# Front-end things
gem 'sass-rails', '~> 5.0'
gem 'autoprefixer-rails'
gem 'imgix'
gem 'uglifier', '>= 1.3.0'
gem 'webpacker'
gem 'turbolinks', '~> 5.1.0'

# Misc
gem 'jbuilder', '~> 2.5'
gem 'sdoc', '~> 1.0', group: :doc
gem 'acts_as_list'
gem 'redcarpet'
gem 'sanitize'
gem 'exifr', require: nil
gem 'acts-as-taggable-on', '~> 6.0'
gem 'httparty'
gem 'kaminari'
gem 'figaro'
gem 'oauth'
gem 'mini_magick'

# Monitoring
gem 'newrelic_rpm'
gem 'sentry-raven'

# Caching
gem 'dalli'

# Background Jobs
gem 'resque'
gem 'resque-scheduler'

# Social Networks
gem 'tumblr_client'
gem 'flickraw'

# Search
gem 'elasticsearch-model', '~> 5.0'
gem 'elasticsearch-rails', '~> 5.0'

group :production do
  gem 'passenger'
  gem 'lograge'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :development, :test do
  gem 'scss-lint'
  gem 'foreman'
  gem 'byebug'
  gem 'brakeman', require: nil
end

group :test do
  gem 'mock_redis'
  gem 'rails-controller-testing'
end
