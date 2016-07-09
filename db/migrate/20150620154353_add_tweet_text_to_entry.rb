class AddTweetTextToEntry < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :tweet_text, :string
  end
end
