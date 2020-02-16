class RemoveLazyLoadRelatedFromBlogs < ActiveRecord::Migration[5.2]
  def up
    remove_column :blogs, :lazy_load_related_entries
  end

  def down
    add_column :blogs, :lazy_load_related_entries, :boolean, default: false
  end
end
