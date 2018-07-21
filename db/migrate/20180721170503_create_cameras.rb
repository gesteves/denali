class CreateCameras < ActiveRecord::Migration[5.2]
  def change
    create_table :cameras do |t|
      t.string :make
      t.string :model
      t.string :slug
      t.string :display_name
      t.boolean :is_phone, default: false

      t.timestamps
    end
  end
end
