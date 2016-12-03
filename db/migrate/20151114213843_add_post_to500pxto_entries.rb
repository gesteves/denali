class AddPostTo500pxtoEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :post_to_500px, :boolean
  end
end
