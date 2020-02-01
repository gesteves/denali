class AddTumblrTagsToTagCustomizations < ActiveRecord::Migration[5.2]
  def change
    add_column :tag_customizations, :tumblr_tags, :text
  end
end
