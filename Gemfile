source 'https://rubygems.org'
ruby '2.5.0'

gem 'rails', '~> 5.1'
gem 'pg', '~> 0.21'

# Auth
gem 'omniauth-google-oauth2'

# Uploads
gem 'aws-sdk', '~> 2.0'
gem 'paperclip', '~> 5.0'

# Front-end things
gem 'sass-rails', '~> 5.0'
gem 'jquery-rails'
gem 'autoprefixer-rails'
gem 'imgix'
gem 'uglifier'

# Misc
gem 'jbuilder', '~> 2.3'
gem 'sdoc', '~> 0.4.0', group: :doc
gem 'acts_as_list'
gem 'redcarpet'
gem 'sanitize'
gem 'exifr', require: nil
gem 'acts-as-taggable-on', '~> 5.0'
gem 'httparty'
gem 'kaminari'
gem 'figaro'
gem 'oauth'
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
gem 'elasticsearch-model'
gem 'elasticsearch-rails'

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
