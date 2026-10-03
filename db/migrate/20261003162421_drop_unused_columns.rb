# The second half of removing these columns. The first (in the release before
# this one) put them in ignored_columns, so by the time this runs no process
# still writes to them. Deploy it only after that release is live.
class DropUnusedColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :photos, :source_url, :string
    remove_column :photos, :dominant_color, :string
    remove_column :photos, :black_and_white, :boolean
    remove_column :blogs, :facebook, :string
    remove_column :users, :oauth_token, :string
    remove_column :users, :oauth_expires_at, :datetime, precision: nil
  end
end
