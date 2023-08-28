class AddBlueskyFieldsToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :post_to_bluesky, :boolean, default: true
    add_column :entries, :bluesky_text, :text
  end
end
