# Raised by MetaShareJob when Meta is still processing a container it made in an earlier attempt.
#
# It isn't a failure: it's how the job waits without holding a Sidekiq thread. The job's
# retry_delay brings it back in a few seconds, and config/initializers/bugsnag.rb discards it, so
# only a share that waits out all of its retries is reported (by JobDeathReporter).
class MetaContainerPendingError < StandardError; end
