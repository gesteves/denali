class AddThreadsTopicToTagCustomizations < ActiveRecord::Migration[8.0]
  def change
    add_column :tag_customizations, :threads_topic, :string
  end
end
