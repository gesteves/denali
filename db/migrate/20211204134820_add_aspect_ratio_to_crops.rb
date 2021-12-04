class AddAspectRatioToCrops < ActiveRecord::Migration[6.1]
  def change
    add_column :crops, :aspect_ratio, :string
    add_index :crops, :aspect_ratio
  end
end
