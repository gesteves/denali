class ElasticsearchJob < ApplicationJob
  # Every photo save touches its entry, and processing a new photo saves it half a dozen times, so
  # updates wait out a burst and reindex once. Creates and deletes happen once each, and go
  # straight through.
  DEBOUNCE = 30.seconds

  # @param entry_id [Integer]
  # @return [void]
  def self.enqueue_update(entry_id)
    enqueue_debounced(entry_id, 'update', window: DEBOUNCE)
  end

  def perform(entry_id, action)
    case action
    when 'create', 'update'
      entry = Entry.find_by(id: entry_id)
      return if entry.blank?

      if action == 'create'
        entry.__elasticsearch__.index_document
      else
        entry.__elasticsearch__.update_document
      end
    when 'delete', 'destroy' # 'destroy' is what jobs enqueued before the rename carry
      # By the time this runs the row is gone, so the document is deleted by ID
      # rather than through a loaded record.
      Entry.__elasticsearch__.client.delete(index: Entry.index_name, id: entry_id, ignore: 404)
    end
  end
end
