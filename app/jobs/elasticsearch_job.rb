class ElasticsearchJob < ApplicationJob
  queue_as :default

  def perform(object, action)
    case action
    when 'create'
      object.__elasticsearch__.index_document
    when 'update'
      object.__elasticsearch__.update_document
    when 'delete'
      object.__elasticsearch__.delete_document
    end
  end
end
