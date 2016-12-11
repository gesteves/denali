source 'https://rubygems.org'
ruby '2.3.1'

gem 'rails', '~> 5.0'
gem 'pg'

# Auth
gem 'omniauth-google-oauth2'

# Uploads
gem 'aws-sdk', '~> 2.0'
gem 'paperclip', '~> 5.0'

# Front-end things
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'jquery-rails'
gem 'autoprefixer-rails'
gem 'imgix'

# Misc
gem 'jbuilder', '~> 2.3'
gem 'sdoc', '~> 0.4.0', group: :doc
gem 'acts_as_list', '~> 0.7.0'
gem 'redcarpet'
gem 'sanitize'
gem 'exifr'
gem 'acts-as-taggable-on', '~> 4.0'
gem 'httparty'
gem 'kaminari'
gem 'figaro'
gem 'oauth'
gem 'htmlentities'
gem 'sentry-raven'
gem 'cloudfront-invalidator'
gem 'rmagick'

# Caching
gem 'dalli'

# Background Jobs
gem 'resque'
gem 'resque-scheduler'

# Social Networks
gem 'tumblr_client'
gem 'flickraw'
gem 'twitter', '~> 5.0'

group :production do
  gem 'passenger'
  gem 'lograge'
end

group :development do
  gem 'web-console', '~> 3.0'
end

group :development, :test do
  gem 'scss-lint'
  gem 'foreman'
  gem 'byebug'
  gem 'spring'
  gem 'brakeman', require: nil
end

group :test do
  gem 'mock_redis'
  gem 'rails-controller-testing'
end
