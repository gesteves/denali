class AddAppleNewsToBlog < ActiveRecord::Migration[5.1]
  def change
    add_column :blogs, :apple_news_url, :string
  end
end
