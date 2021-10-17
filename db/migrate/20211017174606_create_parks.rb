class CreateParks < ActiveRecord::Migration[6.1]
  def change
    create_table :parks do |t|
      t.string :full_name
      t.string :short_name
      t.string :code, index: true
      t.string :designation
      t.string :url
      t.string :slug, index: true

      t.timestamps
    end
  end
end
