class AddInstagramLocationIdAndThreadsLocationIdToParks < ActiveRecord::Migration[8.0]
  def change
    add_column :parks, :instagram_location_id, :string
    add_column :parks, :threads_location_id, :string
  end
end
