class AddRelatedEntriesOptionToBlog < ActiveRecord::Migration
  def change
    add_column :blogs, :show_related_entries, :boolean, default: true
  end
end
