class AddSensitiveToEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :is_sensitive, :boolean, default: false
  end
end
