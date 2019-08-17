class ChangeShareDefault < ActiveRecord::Migration[5.2]
  def change
    change_column_default :entries, :post_to_twitter, true
    change_column_default :entries, :post_to_facebook, true
    change_column_default :entries, :post_to_flickr, true
    change_column_default :entries, :post_to_instagram, true
  end
end
