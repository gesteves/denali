class AddPublishToAppleNewsToBlog < ActiveRecord::Migration[5.1]
  def change
    add_column :blogs, :publish_on_apple_news, :boolean, default: false
  end
end
