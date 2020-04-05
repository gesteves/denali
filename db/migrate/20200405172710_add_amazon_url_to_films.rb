class AddAmazonUrlToFilms < ActiveRecord::Migration[5.2]
  def change
    add_column :films, :amazon_url, :string
  end
end
