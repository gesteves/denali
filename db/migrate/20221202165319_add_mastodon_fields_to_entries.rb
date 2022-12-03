class AddMastodonFieldsToEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :mastodon_text, :text
    add_column :entries, :post_to_mastodon, :boolean, default: true
  end
end
