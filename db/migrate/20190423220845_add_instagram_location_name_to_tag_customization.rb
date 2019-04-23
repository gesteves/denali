class AddInstagramLocationNameToTagCustomization < ActiveRecord::Migration[5.2]
  def change
    add_column :tag_customizations, :instagram_location_name, :string
  end
end
