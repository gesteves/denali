class AddTweetTextToEntry < ActiveRecord::Migration
  def change
    add_column :entries, :tweet_text, :string
  end
end
