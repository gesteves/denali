class AddAmazonUrlToLenses < ActiveRecord::Migration[5.2]
  def change
    add_column :lenses, :amazon_url, :string
  end
end
