class AddStatusToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :published, :boolean
    add_column :entries, :queued, :boolean
    add_column :entries, :draft, :boolean
  end
end
