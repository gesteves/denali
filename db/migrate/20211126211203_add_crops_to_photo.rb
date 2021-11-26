class AddCropsToPhoto < ActiveRecord::Migration[6.1]
  def change
    add_column :photos, :square_crop, :text
    add_column :photos, :facebook_crop, :text
    add_column :photos, :twitter_crop, :text
  end
end
