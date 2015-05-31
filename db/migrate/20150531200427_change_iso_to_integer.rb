class ChangeIsoToInteger < ActiveRecord::Migration
  def self.up
    change_table :photos do |t|
      t.change :iso, :integer
    end
  end
  def self.down
    change_table :photos do |t|
      t.change :iso, :string
    end
  end
end
