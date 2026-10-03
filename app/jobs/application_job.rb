require 'digest'
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

  # Enqueues the job once per window for the same arguments, on the trailing edge, so a burst of
  # calls runs it once, after the burst has settled. Processing a new photo saves it, and so
  # touches its entry, half a dozen times in a minute or two.
  #
  # @param args [Array] the job's arguments. Calls with the same ones share a window.
  # @param window [ActiveSupport::Duration]
  # @return [void]
  def self.enqueue_debounced(*args, window:)
    key = "debounce/#{name.underscore}/#{Digest::MD5.hexdigest(args.to_json)}"
    # The write fails both when the key is already there (a run is pending) and when the cache
    # store is down, whose errors the store swallows. Only the first means skip: skipping during an
    # outage would mean the job never ran at all.
    return if !Rails.cache.write(key, true, unless_exist: true, expires_in: window) && Rails.cache.exist?(key)

    perform_in(window, *args)
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
