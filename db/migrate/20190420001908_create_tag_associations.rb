class CreateTagAssociations < ActiveRecord::Migration[5.2]
  def change
    create_table :tag_associations do |t|
      t.text :instagram_hashtags
      t.text :flickr_groups
      t.references :blog
      t.timestamps
    end
  end
end
