class AddRelatedEntriesOptionToBlog < ActiveRecord::Migration[4.2]
  def change
    add_column :blogs, :show_related_entries, :boolean, default: true
  end
end
