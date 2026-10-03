class CaptionValidityJob < ApplicationJob
  sidekiq_options queue: 'low'

  def perform(entry_id)
    entry = Entry.includes(
      :blog,
      { taggings: :tag },
      { photos: [:camera, :lens, :film, :park] }
    ).find(entry_id)

    entry.update_caption_validity
  rescue ActiveRecord::RecordNotFound
    # Entry was deleted before job ran
  end
end
