class AddSettingsUpdatedAtToBlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :blogs, :settings_updated_at, :datetime, precision: nil
  end
end
