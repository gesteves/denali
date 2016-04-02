class AddCopyrightToBlog < ActiveRecord::Migration
  def change
    add_column :blogs, :copyright, :string
  end
end
