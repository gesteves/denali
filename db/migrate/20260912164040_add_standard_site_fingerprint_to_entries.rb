class AddStandardSiteFingerprintToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :standard_site_fingerprint, :string
  end
end
