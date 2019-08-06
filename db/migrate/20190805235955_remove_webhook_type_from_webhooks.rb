class RemoveWebhookTypeFromWebhooks < ActiveRecord::Migration[5.2]
  def self.up
    remove_column :webhooks, :webhook_type
  end

  def self.down
    add_column :webhooks, :webhook_type, :integer
  end
end
