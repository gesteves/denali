class AddMaxAgeToBlog < ActiveRecord::Migration[4.2]
  def change
    add_column :blogs, :max_age, :integer, default: 5
  end
end
