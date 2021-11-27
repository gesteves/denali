class CreateCrops < ActiveRecord::Migration[6.1]
  def change
    create_table :crops do |t|
      t.float :x
      t.float :y
      t.float :width
      t.float :height
      t.string :name
      t.references :photo, index: true, foreign_key: true
      t.timestamps
    end
  end
end
