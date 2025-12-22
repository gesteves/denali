class CreatePhotoTerritories < ActiveRecord::Migration[8.0]
  def change
    create_table :photo_territories do |t|
      t.references :photo, null: false, foreign_key: true
      t.references :territory, null: false, foreign_key: true

      t.timestamps
    end
    add_index :photo_territories, [:photo_id, :territory_id], unique: true
  end
end
