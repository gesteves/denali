class MigrateTerritoriesDataAndDropColumn < ActiveRecord::Migration[8.0]
  def change
    # The old territories column stored JSON arrays of territory names.
    # We're dropping it and replacing with a proper many-to-many relationship
    # to the new territories table. Run `rake native_lands:update_all` after
    # this migration to repopulate territory data from the API.
    remove_column :photos, :territories, :text
  end
end
