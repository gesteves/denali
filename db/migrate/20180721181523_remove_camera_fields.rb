class RemoveCameraFields < ActiveRecord::Migration[5.2]
  def up
    remove_column :photos, :make
    remove_column :photos, :model
    remove_column :photos, :film_make
    remove_column :photos, :film_type
  end

  def down
    add_column :photos, :make, :string
    add_column :photos, :model, :string
    add_column :photos, :film_make, :string
    add_column :photos, :film_type, :string
  end
end
