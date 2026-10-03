# See RetagsEntries.
class RetagEntriesJob < ApplicationJob
  sidekiq_options queue: 'low'

  MODELS = %w[Camera Lens Film Park].freeze

  def perform(model_name, id)
    return unless MODELS.include?(model_name)

    model_name.constantize.find_by(id: id)&.update_entry_tags
  end
end
