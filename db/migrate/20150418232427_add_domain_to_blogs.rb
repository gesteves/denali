class AddDomainToBlogs < ActiveRecord::Migration
  def change
    add_column :blogs, :domain, :string
    add_index :blogs, :domain
  end
end
