class AddFlickrToBlog < ActiveRecord::Migration[5.1]
  def change
    add_column :blogs, :flickr, :string
  end
end
