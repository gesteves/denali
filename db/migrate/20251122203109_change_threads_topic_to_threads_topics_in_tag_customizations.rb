class ChangeThreadsTopicToThreadsTopicsInTagCustomizations < ActiveRecord::Migration[8.0]
  def change
    rename_column :tag_customizations, :threads_topic, :threads_topics
    change_column :tag_customizations, :threads_topics, :text
  end
end
