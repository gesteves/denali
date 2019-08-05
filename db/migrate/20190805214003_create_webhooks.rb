class CreateWebhooks < ActiveRecord::Migration[5.2]
  def change
    create_table :webhooks do |t|
      t.string :url
      t.integer :webhook_type
      t.references :blog, foreign_key: true

      t.timestamps
    end
  end
end
