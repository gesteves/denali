class CreateSocialAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :social_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid
      t.string :handle
      t.text :access_token
      t.string :server_url
      t.datetime :connected_at
      t.timestamps
    end

    add_index :social_accounts, [:user_id, :provider], unique: true
    add_index :social_accounts, [:provider, :uid], unique: true
  end
end
