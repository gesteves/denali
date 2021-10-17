class RenameParkCodeColumn < ActiveRecord::Migration[6.1]
  def change
    rename_column :photos, :park_code, :location
  end
end
