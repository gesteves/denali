class CreateLenses < ActiveRecord::Migration[5.2]
  def change
    create_table :lenses do |t|
      t.string :make
      t.string :model
      t.string :slug
      t.string :display_name

      t.timestamps
    end
  end
end
