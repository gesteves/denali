class RemovePinterestFromEntries < ActiveRecord::Migration
  def self.up
    remove_column :entries, :post_to_pinterest
  end

  def self.down
    add_column :entries, :post_to_pinterest, :boolean
  end
end
