class CreateFilms < ActiveRecord::Migration[5.2]
  def change
    create_table :films do |t|
      t.string :make
      t.string :model
      t.string :slug
      t.string :display_name

      t.timestamps
    end
  end
end
