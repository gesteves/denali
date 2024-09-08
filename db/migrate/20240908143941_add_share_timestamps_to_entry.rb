class AddShareTimestampsToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :last_shared_on_instagram_at, :datetime
    add_column :entries, :last_shared_on_bluesky_at, :datetime
    add_column :entries, :last_shared_on_mastodon_at, :datetime
  end
end
