class AddShortDomainToBlog < ActiveRecord::Migration
  def change
    add_column :blogs, :short_domain, :string
  end
end
