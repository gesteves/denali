source 'https://rubygems.org'
ruby '2.6.6'

gem 'rails', '5.2.4.3'
gem 'pg', '~> 1.2'
gem 'puma'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Auth
gem 'omniauth-google-oauth2'

# AWS
gem 'aws-sdk-cloudfront', '~> 1'
gem 'aws-sdk-s3', '~> 1'

# Front-end things
gem 'sass-rails', '~> 5.0'
gem 'autoprefixer-rails'
gem 'imgix'
gem 'uglifier', '>= 1.3.0'
gem 'webpacker'
gem 'turbolinks', '~> 5.1.0'

# Misc
gem 'jbuilder', '~> 2.10'
gem 'sdoc', '~> 1.0', group: :doc
gem 'acts_as_list'
gem 'redcarpet'
gem 'sanitize'
gem 'exifr', require: nil
gem 'acts-as-taggable-on', '~> 6.5'
gem 'httparty'
gem 'kaminari'
gem 'figaro'
gem 'oauth'
gem 'mini_magick'
gem 'rack-attack'

# Monitoring
gem 'sentry-raven'
gem 'barnes'
gem 'skylight'

# Caching
gem 'dalli'

# Background Jobs
gem 'sidekiq'

# Social Networks
gem 'flickraw', git: 'https://github.com/gesteves/flickraw.git', branch: 'update-upload-url'
gem 'tumblr_client', git: 'https://github.com/gesteves/tumblr_client', branch: 'master'

# Search
gem 'elasticsearch-model', '~> 6.1'
gem 'elasticsearch-rails', '~> 5.0'

gem 'graphql'

group :production do
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
  gem 'byebug'
  gem 'brakeman', require: nil
end

group :test do
  gem 'mock_redis'
  gem 'rails-controller-testing'
end
