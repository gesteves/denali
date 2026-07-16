class BlueskyJob < ApplicationJob
  sidekiq_options queue: 'high'

  def perform(entry_id, text, in_reply_to = nil, quote = nil)
    return unless Rails.env.production?

    entry = Entry.published.find(entry_id)
    return unless entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    account = entry.user&.bluesky_account
    return if account.nil?

    bluesky = Bluesky.from_social_account(account)

    photos = entry.photos.take(Bluesky::MAX_PHOTOS).map do |p|
      { url: p.bluesky_url, alt_text: p.alt_text, width: p.width, height: p.height }
    end

    response = bluesky.skeet(text: text, photos: photos, in_reply_to: in_reply_to, quote: quote)

    # Threadgates only apply to root posts; replies inherit the root post's gate.
    BlueskyThreadgateJob.perform_async(entry_id, response["uri"]) if in_reply_to.blank? && response["uri"].present?

    unless in_reply_to.present? || quote.present?
      entry.update_columns(
        last_shared_on_bluesky_at: Time.current,
        bluesky_shares_count: entry.bluesky_shares_count + 1
      )
    end
  end
end
