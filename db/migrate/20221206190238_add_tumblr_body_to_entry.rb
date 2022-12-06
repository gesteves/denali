class AddTumblrBodyToEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :tumblr_text, :text
  end
end
