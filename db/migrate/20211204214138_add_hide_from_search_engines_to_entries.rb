class AddHideFromSearchEnginesToEntries < ActiveRecord::Migration[6.1]
  def change
    add_column :entries, :hide_from_search_engines, :boolean, default: false
  end
end
