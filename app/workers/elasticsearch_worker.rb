class ElasticsearchWorker < ApplicationWorker
  def perform(entry_id, action)
    begin
      entry = Entry.find(entry_id)
    rescue ActiveRecord::RecordNotFound
      return
    end
    case action
    when 'create'
      entry.__elasticsearch__.index_document
    when 'update'
      entry.__elasticsearch__.update_document
    when 'delete'
      entry.__elasticsearch__.delete_document
    end
  end
end
