class MovePublicKey < ActiveRecord::Migration[7.0]
  def change
    add_column :blogs, :public_key, :text
    remove_column :profiles, :public_key
  end
end
