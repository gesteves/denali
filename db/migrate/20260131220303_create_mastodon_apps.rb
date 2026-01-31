class CreateMastodonApps < ActiveRecord::Migration[8.1]
  def change
    create_table :mastodon_apps do |t|
      t.string :instance_url, null: false
      t.string :client_id, null: false
      t.text :client_secret, null: false

      t.timestamps
    end

    add_index :mastodon_apps, :instance_url, unique: true
  end
end
