class AddHideFromSearchEnginesIndexToEntries < ActiveRecord::Migration[6.1]
  def change
    add_index :entries, :hide_from_search_engines
  end
end
