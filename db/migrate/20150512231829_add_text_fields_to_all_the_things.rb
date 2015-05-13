class AddTextFieldsToAllTheThings < ActiveRecord::Migration
  def change
    add_column :entries, :html_body, :text
    add_column :entries, :plain_body, :text

    add_column :photos, :html_caption, :text
    add_column :photos, :plain_caption, :text

    add_column :blogs, :html_description, :text
    add_column :blogs, :plain_description, :text
  end
end
