class AddLogoToBlog < ActiveRecord::Migration[5.1]
  def change
    add_column :blogs, :logo_file_name, :string
    add_column :blogs, :logo_content_type, :string
    add_column :blogs, :logo_file_size, :integer
    add_column :blogs, :logo_updated_at, :datetime
  end
end
