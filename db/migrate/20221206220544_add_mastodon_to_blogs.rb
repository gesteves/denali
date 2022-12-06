class AddMastodonToBlogs < ActiveRecord::Migration[7.0]
  def change
    add_column :blogs, :mastodon, :string
  end
end
