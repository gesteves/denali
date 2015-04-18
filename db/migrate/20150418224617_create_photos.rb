class CreatePhotos < ActiveRecord::Migration
  def change
    create_table :photos do |t|
      t.text :caption
      t.integer :position
      t.references :entry, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
