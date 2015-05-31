class ChangeFocalLengthToInteger < ActiveRecord::Migration
  def self.up
    change_table :photos do |t|
      t.change :focal_length, :integer
    end
  end
  def self.down
    change_table :photos do |t|
      t.change :focal_length, :string
    end
  end
end
