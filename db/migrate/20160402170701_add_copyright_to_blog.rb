class AddCopyrightToBlog < ActiveRecord::Migration[4.2]
  def change
    add_column :blogs, :copyright, :string
  end
end
