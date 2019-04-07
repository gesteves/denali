class RemoveKeywordsFromPhotos < ActiveRecord::Migration[5.2]
  def self.up
    remove_column :photos, :keywords
  end

  def self.down
    add_column :photos, :keywords, :string
  end
end
