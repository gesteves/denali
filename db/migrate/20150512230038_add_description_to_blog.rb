class AddDescriptionToBlog < ActiveRecord::Migration
  def change
    add_column :blogs, :description, :text
  end
end
