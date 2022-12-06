class RemovePublicKeyFromBlog < ActiveRecord::Migration[7.0]
  def up
    remove_column :blogs, :public_key
  end

  def down
    add_column :blogs, :public_key, :text
  end
end
