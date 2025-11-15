class AddInstagramRowsAgain < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :post_to_instagram, :boolean, default: true
    add_column :entries, :instagram_text, :text
    add_column :entries, :last_shared_on_instagram_at, :datetime
  end
end
