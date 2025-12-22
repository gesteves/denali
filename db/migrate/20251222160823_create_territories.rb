class CreateTerritories < ActiveRecord::Migration[8.0]
  def change
    create_table :territories do |t|
      t.string :slug
      t.string :name
      t.string :url

      t.timestamps
    end
    add_index :territories, :slug, unique: true
  end
end
