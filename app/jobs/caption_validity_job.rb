class CaptionValidityJob < ApplicationJob
  sidekiq_options queue: 'low'

  # The captions carry the photos' places and equipment, which the photo jobs fill in one after
  # another, so the check waits out the burst and runs once.
  DEBOUNCE = 30.seconds

  # @param entry_id [Integer]
  # @return [void]
  def self.enqueue(entry_id)
    enqueue_debounced(entry_id, window: DEBOUNCE)
  end

  def perform(entry_id)
    entry = Entry.with_share_includes.find(entry_id)

    entry.update_caption_validity
  rescue ActiveRecord::RecordNotFound
    # Entry was deleted before job ran
  end
end
