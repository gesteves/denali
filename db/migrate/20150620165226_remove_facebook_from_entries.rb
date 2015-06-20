class RemoveFacebookFromEntries < ActiveRecord::Migration
  def self.up
    remove_column :entries, :post_to_facebook
  end

  def self.down
    add_column :entries, :post_to_facebook, :boolean
  end
end
