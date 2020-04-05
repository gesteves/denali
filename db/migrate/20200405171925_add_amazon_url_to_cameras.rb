class AddAmazonUrlToCameras < ActiveRecord::Migration[5.2]
  def change
    add_column :cameras, :amazon_url, :string
  end
end
