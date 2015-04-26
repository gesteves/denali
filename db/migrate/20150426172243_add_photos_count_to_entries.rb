class AddPhotosCountToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :photos_count, :integer
  end
end
