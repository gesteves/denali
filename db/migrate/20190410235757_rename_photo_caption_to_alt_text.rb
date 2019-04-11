class RenamePhotoCaptionToAltText < ActiveRecord::Migration[5.2]
  def change
    rename_column :photos, :caption, :alt_text
  end
end
