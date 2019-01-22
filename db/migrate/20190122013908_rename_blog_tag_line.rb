class RenameBlogTagLine < ActiveRecord::Migration[5.2]
  def change
    rename_column :blogs, :description, :tag_line
  end
end
