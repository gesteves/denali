class AddTimeZoneToBlogs < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :time_zone, :string, default: 'UTC'
  end
end
