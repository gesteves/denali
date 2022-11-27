class AddPublicKeyToProfile < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :public_key, :text
  end
end
