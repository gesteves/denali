class AddAboutToBlog < ActiveRecord::Migration
  def change
    add_column :blogs, :about, :text
  end
end
