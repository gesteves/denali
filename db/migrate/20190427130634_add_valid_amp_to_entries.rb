class AddValidAmpToEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :valid_amp, :boolean, default: true
  end
end
