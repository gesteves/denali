class RemoveStaticTextFieldsFromBlogs < ActiveRecord::Migration[8.0]
  def change
    remove_column :blogs, :tag_line, :text
    remove_column :blogs, :copyright, :string
    remove_column :blogs, :elsewhere_heading, :string
    remove_column :blogs, :elsewhere_cta, :string
    remove_column :blogs, :push_notifications_heading, :string
    remove_column :blogs, :push_notifications_cta, :string
  end
end
