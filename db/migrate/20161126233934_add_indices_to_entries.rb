class AddIndicesToEntries < ActiveRecord::Migration[5.0]
  def change
    add_index :entries, :published_at
    add_index :entries, :show_in_map
    add_index :entries, :photos_count
    add_index :entries, :status
    add_index :photos, :latitude
    add_index :photos, :longitude
  end
end
