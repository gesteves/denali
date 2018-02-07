class AddKeywordsToPhotos < ActiveRecord::Migration[5.1]
  def change
    add_column :photos, :keywords, :string
  end
end
