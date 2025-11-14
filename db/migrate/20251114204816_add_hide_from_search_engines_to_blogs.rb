class AddHideFromSearchEnginesToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :hide_from_search_engines, :boolean, default: false
  end
end
