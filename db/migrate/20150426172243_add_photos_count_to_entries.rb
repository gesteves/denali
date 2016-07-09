class AddPhotosCountToEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :photos_count, :integer
  end
end
