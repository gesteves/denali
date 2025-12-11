class AddValidCaptionColumnsToEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :valid_bluesky_caption, :boolean, default: true, null: false
    add_column :entries, :valid_mastodon_caption, :boolean, default: true, null: false
    add_column :entries, :valid_instagram_caption, :boolean, default: true, null: false
    add_column :entries, :valid_threads_caption, :boolean, default: true, null: false
  end
end
