# What posting an entry to a social network has in common, whichever network it is.
class ShareJob < ApplicationJob
  # A share is about something that was just published (or picked for today), so
  # one that's still failing after six hours is better dropped than posted weeks
  # late, which is where Sidekiq's default 25 retries would take it. Dying, it's
  # reported to Bugsnag (see JobDeathReporter).
  sidekiq_options queue: 'high', retry_for: 6.hours.to_i

  private

  # The entry to share, or nil when there's nothing to do: not in production, or
  # the entry was unpublished or deleted since this was enqueued, or it has no
  # photos.
  #
  # @raise [UnprocessedPhotoError] until every photo's dimensions are recorded.
  def shareable_entry(entry_id)
    return unless Rails.env.production?

    entry = Entry.published.find_by(id: entry_id)
    return unless entry&.is_photo?

    # The photo jobs normally analyze the images first, but a share can get
    # there before them; analyzing here beats waiting for a retry to line up.
    entry.photos.each(&:ensure_analyzed!)
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    entry
  end

  # Counts the share in a single UPDATE, so two shares finishing at once can't
  # both read the old count and write the same new one.
  #
  # @param platform [String] 'bluesky', 'mastodon', 'instagram' or 'threads'.
  def record_share(entry, platform)
    Entry.update_counters(entry.id, "#{platform}_shares_count": 1, touch: :"last_shared_on_#{platform}_at")
  end
end
