class RemovePhotoQualityFromBlogs < ActiveRecord::Migration
  def self.up
    remove_column :blogs, :photo_quality
  end

  def self.down
    add_column :blogs, :photo_quality, :integer, default: 90
  end
end
