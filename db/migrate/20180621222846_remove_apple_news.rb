class RemoveAppleNews < ActiveRecord::Migration[5.1]
  def up
    remove_column :entries, :apple_news_id
    remove_column :blogs, :apple_news_url
    remove_column :blogs, :publish_on_apple_news
  end

  def down
    add_column :blogs, :apple_news_url, :string
    add_column :blogs, :publish_on_apple_news, :boolean, default: false
    add_column :entries, :apple_news_id, :string
  end
end
