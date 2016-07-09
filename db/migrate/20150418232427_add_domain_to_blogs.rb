class AddDomainToBlogs < ActiveRecord::Migration[4.2]
  def change
    add_column :blogs, :domain, :string
    add_index :blogs, :domain
  end
end
