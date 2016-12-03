class Remove500pxFromEntries < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :entries, :post_to_500px
  end

  def self.down
    add_column :entries, :post_to_500px, :boolean
  end
end
