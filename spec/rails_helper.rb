# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_group 'Jobs', 'app/jobs'
  add_group 'Libraries', 'lib'
end

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# Add additional requires below this line. Rails is not loaded until this point!
require 'webmock/rspec'
require 'vcr'
require 'sidekiq/testing'
require 'rspec-sidekiq'

# Configure OmniAuth for testing
OmniAuth.config.test_mode = true
OmniAuth.config.silence_get_warning = true

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories.
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# VCR configuration for recording API interactions
VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
  # Allow WebMock stubs to work when no VCR cassette is in use
  config.allow_http_connections_when_no_cassette = true

  # Filter out sensitive data
  config.filter_sensitive_data('<API_KEY>') { ENV['API_KEY'] }
  config.filter_sensitive_data('<BLUESKY_APP_PASSWORD>') { ENV['BLUESKY_APP_PASSWORD'] }
  config.filter_sensitive_data('<MASTODON_ACCESS_TOKEN>') { ENV['MASTODON_ACCESS_TOKEN'] }
  config.filter_sensitive_data('<INSTAGRAM_ACCESS_TOKEN>') { ENV['INSTAGRAM_ACCESS_TOKEN'] }
  config.filter_sensitive_data('<THREADS_ACCESS_TOKEN>') { ENV['THREADS_ACCESS_TOKEN'] }
  config.filter_sensitive_data('<FLICKR_ACCESS_TOKEN>') { ENV['FLICKR_ACCESS_TOKEN'] }
  config.filter_sensitive_data('<CLAUDE_API_KEY>') { ENV['CLAUDE_API_KEY'] }
end

# Configure shoulda-matchers
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs.
  # Automatically infer spec type from file location
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Include ActiveSupport time helpers (travel_to, etc.)
  config.include ActiveSupport::Testing::TimeHelpers

  # Sidekiq testing mode
  config.before(:each) do
    Sidekiq::Testing.fake!
    Sidekiq::Job.clear_all
  end

  # Set ActiveStorage URL options for tests
  config.before(:each) do
    ActiveStorage::Current.url_options = { host: 'localhost', port: 3000 }
  end

  # WebMock - disable all external HTTP requests by default
  config.before(:each) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  # Helper method to attach images to photos
  config.include Module.new {
    def attach_image_to_photo(photo, filename: 'rusty.jpg')
      photo.image.attach(
        io: File.open(Rails.root.join('spec/fixtures/images/rusty.jpg')),
        filename: filename
      )
      photo.image.analyze
      # Reload the photo to ensure image metadata is accessible
      photo.reload
    end

    def set_up_images(entry)
      entry.photos.each do |photo|
        attach_image_to_photo(photo)
      end
    end

    def set_up_all_images
      Photo.all.each do |photo|
        attach_image_to_photo(photo)
      end
    end
  }
end

# RSpec Sidekiq configuration
RSpec::Sidekiq.configure do |config|
  config.warn_when_jobs_not_processed_by_sidekiq = false
end
