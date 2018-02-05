class RemoveKeywordsFromPhoto < ActiveRecord::Migration[5.1]
  def self.up
    remove_column :photos, :keywords
    remove_column :photos, :dominant_color
  end

  def self.down
    add_column :photos, :keywords, :string
    add_column :photos, :dominant_color, :string
  end
end
