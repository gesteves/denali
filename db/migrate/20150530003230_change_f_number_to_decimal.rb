class ChangeFNumberToDecimal < ActiveRecord::Migration
  def self.up
    change_table :photos do |t|
      t.change :f_number, :decimal
    end
  end
  def self.down
    change_table :photos do |t|
      t.change :f_number, :string
    end
  end
end
