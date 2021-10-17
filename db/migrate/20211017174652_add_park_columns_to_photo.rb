class AddParkColumnsToPhoto < ActiveRecord::Migration[6.1]
  def up
    remove_column :photos, :park
    add_column :photos, :park_code, :string
    add_reference :photos, :park, index: true
  end

  def down
    add_column :photos, :park, :string
    remove_column :photos, :park_code
    remove_reference :photos, :park
  end
end
