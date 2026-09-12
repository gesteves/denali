class AddStandardSiteToBlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :blogs, :standard_site_social_account_id, :integer
    add_index :blogs, :standard_site_social_account_id
    add_column :blogs, :standard_site_did, :string
    add_column :blogs, :standard_site_fingerprint, :string
  end
end
