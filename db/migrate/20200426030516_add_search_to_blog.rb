class AddSearchToBlog < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :show_search, :boolean, default: false
  end
end
