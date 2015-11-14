class AddPostTo500pxtoEntries < ActiveRecord::Migration
  def change
    add_column :entries, :post_to_500px, :boolean
  end
end
