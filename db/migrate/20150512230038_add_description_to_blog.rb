class AddDescriptionToBlog < ActiveRecord::Migration[4.2]
  def change
    add_column :blogs, :description, :text
  end
end
