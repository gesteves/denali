class AddTumblrToEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :post_to_tumblr, :boolean, default: true
  end
end
