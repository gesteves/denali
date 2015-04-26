class AddPhotosCountToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :photos_count, :integer, default: 0
  end
end
