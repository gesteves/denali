class CaptionValidityJob < ApplicationJob
  sidekiq_options queue: 'low'

  def perform(entry_id)
    entry = Entry.includes(
      :blog,
      { taggings: :tag },
      { photos: [:camera, :lens, :film, :park] }
    ).find(entry_id)

    # Preload all tag_customizations to avoid 4 separate queries
    entry.blog.tag_customizations.load

    entry.update_columns(
      valid_bluesky_caption: Bluesky.valid_post_length?(entry.bluesky_caption),
      valid_mastodon_caption: entry.mastodon_caption.length <= 500,
      valid_instagram_caption: entry.instagram_caption.length <= 2200,
      valid_threads_caption: entry.threads_caption.length <= 500
    )
  rescue ActiveRecord::RecordNotFound
    # Entry was deleted before job ran
  end
end
