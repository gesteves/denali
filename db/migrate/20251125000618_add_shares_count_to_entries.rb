class AddSharesCountToEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :bluesky_shares_count, :integer, default: 0, null: false
    add_column :entries, :mastodon_shares_count, :integer, default: 0, null: false
    add_column :entries, :instagram_shares_count, :integer, default: 0, null: false
    add_column :entries, :threads_shares_count, :integer, default: 0, null: false

    add_index :entries, :bluesky_shares_count
    add_index :entries, :mastodon_shares_count
    add_index :entries, :instagram_shares_count
    add_index :entries, :threads_shares_count
  end
end
