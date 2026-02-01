class RemoveAmazonUrlFromEquipment < ActiveRecord::Migration[8.1]
  def change
    remove_column :cameras, :amazon_url, :string
    remove_column :films, :amazon_url, :string
    remove_column :lenses, :amazon_url, :string
  end
end
