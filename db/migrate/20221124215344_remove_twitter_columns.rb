class RemoveTwitterColumns < ActiveRecord::Migration[7.0]
  def up
    remove_column :entries, :tweet_text
    remove_column :entries, :post_to_twitter
    remove_column :blogs, :twitter
  end

  def down
    add_column :entries, :tweet_text, :string
    add_column :entries, :post_to_twitter, :boolean, default: true
    add_column :blogs, :twitter, :string
  end
end
