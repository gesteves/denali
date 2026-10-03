# Tells Bugsnag when Sidekiq gives up on a job, whether its retries ran out or
# its retry rules discarded it.
#
# Each failed attempt is already reported as it happens, except for the error
# classes config/initializers/bugsnag.rb discards because they're expected to
# clear up on a retry (an unprocessed photo, a transient Meta error). When they
# don't, the post they were for is lost without a trace, so the death is
# reported as an error of its own, which those discards don't match.
module JobDeathReporter
  class JobDied < StandardError; end

  # @param job [Hash] the Sidekiq job payload.
  # @param exception [Exception] the error from the last attempt.
  def self.call(job, exception)
    outcome = job.key?('discarded_at') ? 'discarded' : "gave up after #{job['retry_count'].to_i + 1} retries"
    error = JobDied.new("#{job['class']} #{outcome}: #{exception.class}: #{exception.message}")
    error.set_backtrace(exception.backtrace) if exception.backtrace

    Bugsnag.notify(error) do |report|
      report.add_metadata(:sidekiq, { jid: job['jid'], queue: job['queue'], args: job['args'], error_class: exception.class.name })
    end
  end
end
