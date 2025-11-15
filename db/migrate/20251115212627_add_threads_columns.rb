class AddThreadsColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :post_to_threads, :boolean, default: true
    add_column :entries, :threads_text, :text
    add_column :entries, :last_shared_on_threads_at, :datetime
  end
end
