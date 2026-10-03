require_relative "boot"

require "rails"
# Only the frameworks the app uses; rails/all would also load Action Mailer,
# Action Cable, Action Text and Action Mailbox, which it doesn't.
require "active_record/railtie"
require "active_storage/engine"
require "active_job/railtie" # Active Storage analyzes and purges through it
require "action_controller/railtie"
require "action_view/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Denali
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Nothing uses Active Storage's own URLs (images go through Cloudflare), and
    # its routes include a public direct-upload endpoint that hands out
    # pre-signed upload URLs to the bucket.
    config.active_storage.draw_routes = false

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
