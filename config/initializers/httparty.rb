# A default for every HTTParty call that doesn't set its own timeout (open, read
# and write). Net::HTTP's own defaults are a minute each, long enough for a hung
# API to hold a Puma thread or a Sidekiq thread for minutes. Calls that need
# longer (Claude) pass their own.
HTTParty::Basement.default_timeout(30)
