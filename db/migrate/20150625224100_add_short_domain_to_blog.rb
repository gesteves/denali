class AddShortDomainToBlog < ActiveRecord::Migration[4.2]
  def change
    add_column :blogs, :short_domain, :string
  end
end
