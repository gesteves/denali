class AddPaginationOptionsToBlog < ActiveRecord::Migration
  def change
    add_column :blogs, :posts_per_page, :integer, default: 10
  end
end
