class AddAppleNewsIdToEntries < ActiveRecord::Migration[5.1]
  def change
    add_column :entries, :apple_news_id, :string
  end
end
