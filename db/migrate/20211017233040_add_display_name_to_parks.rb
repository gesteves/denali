class AddDisplayNameToParks < ActiveRecord::Migration[6.1]
  def change
    add_column :parks, :display_name, :string
  end
end
