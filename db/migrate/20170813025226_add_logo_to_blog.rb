class AddLogoToBlog < ActiveRecord::Migration[5.1]
  def up
    add_attachment :blogs, :logo
  end

  def down
    remove_attachment :blogs, :logo
  end
end
