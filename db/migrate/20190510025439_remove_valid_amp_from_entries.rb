class RemoveValidAmpFromEntries < ActiveRecord::Migration[5.2]
  def self.up
    remove_column :entries, :valid_amp
  end

  def self.down
    add_column :entries, :valid_amp, :boolean, default: true
  end
end
