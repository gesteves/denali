# Does one standard.site PDS sync, outside the request that caused it.
#
# Every operation can be done more than once: putRecord makes or replaces a record, and a delete of
# a record that isn't there is not an error. So the retries are safe.
class StandardSiteJob < ApplicationJob
  # Reconciliation, not a share someone is waiting on.
  sidekiq_options queue: 'low'

  # ⚠️ sidekiq_retry_in lives in sidekiq_options, so this block REPLACES ApplicationJob's rather
  # than adding to it. Both branches have to be here, or the UnprocessedPhotoError backoff is
  # silently lost.
  sidekiq_retry_in do |count, exception|
    case exception
    when Bluesky::AuthenticationError
      # Credentials the PDS refuses don't get better by trying again for a day.
      :discard
    when AtProto::RateLimitedError
      # The PDS told us when it will accept writes again, so wait that long rather than burning
      # retries against a limit that hasn't lifted.
      exception.retry_after
    when UnprocessedPhotoError
      count + 1
    end
  end

  # @param operation [String] 'sync_document', 'delete_document' or 'sync_publication'.
  # @param entry_id [Integer, nil] the entry's id. 'sync_publication' doesn't use it.
  # @return [void]
  def perform(operation, entry_id = nil)
    return unless Rails.env.production?

    blog = Blog.first
    service = StandardSite.from_blog(blog)
    return if service.nil?

    case operation
    when 'sync_document'    then service.sync_document(entry_id)
    when 'delete_document'  then service.delete_document(entry_id)
    when 'sync_publication' then service.sync_publication
    else
      Rails.logger.warn("StandardSiteJob: unknown operation #{operation.inspect}; ignoring")
    end
  end
end
