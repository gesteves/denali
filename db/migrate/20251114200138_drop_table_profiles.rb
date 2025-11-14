class DropTableProfiles < ActiveRecord::Migration[8.0]
  def change
    drop_table :profiles
  end
end
