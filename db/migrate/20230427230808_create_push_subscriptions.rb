class CreatePushSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :push_subscriptions do |t|
      t.string :endpoint
      t.string :p256dh
      t.string :auth
      t.references :blog, foreign_key: true

      t.timestamps
    end
  end
end
