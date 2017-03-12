class RemoveSlack < ActiveRecord::Migration[5.0]
  def self.up
    remove_column :entries, :post_to_slack
    drop_table :slack_incoming_webhooks
  end

  def self.down
    add_column :entries, :post_to_slack, :boolean
    create_table :slack_incoming_webhooks do |t|
      t.string :team_name
      t.string :team_id
      t.string :url
      t.string :channel
      t.string :configuration_url
      t.references :blog, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
