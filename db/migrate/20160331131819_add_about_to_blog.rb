class AddAboutToBlog < ActiveRecord::Migration[4.2]
  def change
    add_column :blogs, :about, :text
  end
end
