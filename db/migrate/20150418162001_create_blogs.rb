class CreateBlogs < ActiveRecord::Migration
  def change
    create_table :blogs do |t|
      t.string :name
      t.integer :photo_quality, default: 90

      t.timestamps null: false
    end
  end
end
