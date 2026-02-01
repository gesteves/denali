class AddAccessTokenSecretToSocialAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :social_accounts, :access_token_secret, :text
  end
end
