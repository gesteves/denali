# Convenience exception to quietly force a Sidekiq job to retry;
# ignored in Sentry so it doesn't cause any alerts.
class RetrySidekiq < StandardError; end
