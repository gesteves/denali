class CreateProfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :profiles do |t|
      t.string :username
      t.string :name
      t.string :instagram
      t.string :tumblr
      t.string :flickr
      t.string :email
      t.string :summary
      t.text :bio
      t.string :meta_description

      t.references :photo, foreign_key: true
      t.references :user, foreign_key: true
      t.timestamps
    end
    add_index :profiles, :username
  end
end
