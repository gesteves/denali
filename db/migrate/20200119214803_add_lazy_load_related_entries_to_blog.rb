class AddLazyLoadRelatedEntriesToBlog < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :lazy_load_related_entries, :boolean, default: false
  end
end
