class AddCwToEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :content_warning, :string
  end
end
