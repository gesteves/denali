require 'capybara/cuprite'

# System specs run in headless Chrome through Cuprite (the Chrome DevTools
# protocol, no Selenium or chromedriver). Chromium is in the dev image; CI's
# runners have Chrome.
# Its own name: `driven_by :cuprite` would have Rails register a cuprite driver
# of its own, without these options.
Capybara.register_driver(:headless_chrome) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [1280, 900],
    # Docker runs Chromium as root, which its sandbox refuses, and gives it a
    # /dev/shm too small for its shared memory.
    browser_options: { 'no-sandbox' => nil, 'disable-dev-shm-usage' => nil, 'disable-gpu' => nil },
    process_timeout: 30,
    timeout: 15,
    # A JavaScript error on the page fails the spec.
    js_errors: true,
    # Only the app itself: no Font Awesome kit, CDN images or analytics, so a
    # spec never waits on (or depends on) the network.
    url_blacklist: [%r{\Ahttps?://(?!127\.0\.0\.1|localhost)}]
  )
end

Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }
# Where config/environments/test.rb says the app lives, so the absolute URLs it
# generates (canonical links, the page URLs infinite scroll writes to the
# address bar) point back at the server under test.
Capybara.server_host = 'localhost'
Capybara.server_port = 3000

RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :headless_chrome }

  # The test environment turns forgery protection off, which drops the CSRF meta
  # tag the admin's controllers read; system specs run with it on, as production
  # does.
  config.around(:each, type: :system) do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
