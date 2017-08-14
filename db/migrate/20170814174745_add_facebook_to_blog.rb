class AddFacebookToBlog < ActiveRecord::Migration[5.1]
  def change
    add_column :blogs, :facebook, :string
  end
end
