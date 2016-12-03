class CreateSlackIncomingWebhooks < ActiveRecord::Migration[4.2]
  def change
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
