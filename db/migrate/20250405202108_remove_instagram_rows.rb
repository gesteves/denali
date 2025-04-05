class RemoveInstagramRows < ActiveRecord::Migration[8.0]
  def change
    # Remove Instagram columns from blogs table
    remove_column :blogs, :instagram, :string

    # Remove Instagram columns from entries table
    remove_column :entries, :post_to_instagram, :boolean
    remove_column :entries, :instagram_text, :text
    remove_column :entries, :last_shared_on_instagram_at, :datetime

    # Remove Instagram columns from profiles table
    remove_column :profiles, :instagram, :string
  end
end
