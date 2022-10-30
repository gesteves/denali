class AddTumblrTagsAgainToTagCustomizations < ActiveRecord::Migration[7.0]
  def change
    add_column :tag_customizations, :tumblr_tags, :text
  end
end
