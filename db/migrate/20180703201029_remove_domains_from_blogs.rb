class RemoveDomainsFromBlogs < ActiveRecord::Migration[5.2]
  def up
    remove_column :blogs, :domain
    remove_column :blogs, :short_domain
  end

  def down
    add_column :blogs, :domain, :string
    add_column :blogs, :short_domain, :string
  end
end
