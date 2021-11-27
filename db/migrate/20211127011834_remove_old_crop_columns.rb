class RemoveOldCropColumns < ActiveRecord::Migration[6.1]
  def change
    remove_column :photos, :square_crop
    remove_column :photos, :facebook_crop
    remove_column :photos, :twitter_crop
  end

  def down
    add_column :photos, :square_crop, :text
    add_column :photos, :facebook_crop, :text
    add_column :photos, :twitter_crop, :text
  end
end
