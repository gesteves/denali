class AddMaxAgeToBlog < ActiveRecord::Migration
  def change
    add_column :blogs, :max_age, :integer, default: 5
  end
end
