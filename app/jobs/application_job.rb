require 'open-uri'
class ApplicationJob
  include Sidekiq::Job
  sidekiq_options queue: 'default'

  # The longest wait between attempts for a photo that hasn't been analyzed yet.
  MAX_UNPROCESSED_PHOTO_DELAY = 10.minutes.to_i

  # Every job gets a retry block that asks its own class's retry_delay. A job with
  # rules of its own overrides retry_delay and calls super for the rest, rather
  # than declaring sidekiq_retry_in: that replaces the block wholesale, which is
  # how ThreadsJob once lost the unprocessed-photo backoff.
  def self.inherited(subclass)
    super
    subclass.sidekiq_retry_in { |count, exception| subclass.retry_delay(count, exception) }
  end

  # @param count [Integer] how many times the job has been retried so far.
  # @param exception [Exception] what made this attempt fail.
  # @return [Integer, Symbol, nil] seconds until the next attempt, :discard or
  #   :kill, or nil for Sidekiq's default backoff.
  def self.retry_delay(count, exception)
    case exception
    when UnprocessedPhotoError
      # A photo's dimensions usually land within seconds, so the first retries
      # come quickly, then settle at every ten minutes. Sidekiq's 25 retries
      # then cover a couple of hours, where count + 1 seconds ran out in about
      # half an hour (most of it jitter).
      [2**count, MAX_UNPROCESSED_PHOTO_DELAY].min
    end
  end
end
