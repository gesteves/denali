class RemoveStatusFromEntries < ActiveRecord::Migration
  def up
    remove_column :entries, :status
  end

  def down
    add_column :entries, :status, :string
  end
end
