class DropEntryStatusDefault < ActiveRecord::Migration[5.2]
  def up
    change_column_default(:entries, :status, nil)
  end

  def down
    change_column_default(:entries, :status, 'draft')
  end
end
