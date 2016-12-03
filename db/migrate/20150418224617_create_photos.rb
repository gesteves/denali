class CreatePhotos < ActiveRecord::Migration[4.2]
  def change
    create_table :photos do |t|
      t.text :caption
      t.integer :position
      t.references :entry, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
