class ElasticsearchJob < ApplicationJob
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
