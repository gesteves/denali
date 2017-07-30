class ElasticsearchJob < ApplicationJob
  queue_as :default

  def perform(object, action)
    if action == 'create'
      object.__elasticsearch__.index_document
    elsif action == 'update'
      object.__elasticsearch__.update_document
    elsif action == 'destroy'
      object.__elasticsearch__.delete_document
    end
  end
end
