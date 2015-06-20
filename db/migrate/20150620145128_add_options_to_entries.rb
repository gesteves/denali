class AddOptionsToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :post_to_twitter, :boolean
    add_column :entries, :post_to_facebook, :boolean
    add_column :entries, :post_to_tumblr, :boolean
  end
end
