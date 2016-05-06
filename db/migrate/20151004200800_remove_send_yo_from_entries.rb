class RemoveSendYoFromEntries < ActiveRecord::Migration
  def self.up
    remove_column :entries, :send_yo
  end

  def self.down
    add_column :entries, :send_yo, :boolean
  end
end
