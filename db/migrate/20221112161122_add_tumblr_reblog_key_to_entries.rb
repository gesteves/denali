class AddTumblrReblogKeyToEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :tumblr_reblog_key, :string
  end
end
