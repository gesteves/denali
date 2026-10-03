# The models validate these as unique, but validations race: the EXIF jobs for a
# multi-photo upload run at the same time, and each can find no camera with a slug
# and create one. Only the database can promise there's one row per slug.
class AddUniqueIndexesToLookupTables < ActiveRecord::Migration[8.1]
  UNIQUE = {
    cameras: [:slug],
    lenses: [:slug],
    films: [:slug],
    parks: [:code, :slug],
    push_subscriptions: [:endpoint]
  }.freeze

  def up
    remove_duplicate_crops!
    abort_on_duplicates!

    UNIQUE.each do |table, columns|
      columns.each do |column|
        remove_index table, column, if_exists: true
        add_index table, column, unique: true
      end
    end

    # The composite index also serves lookups by photo_id alone.
    remove_index :crops, :photo_id, if_exists: true
    add_index :crops, [:photo_id, :aspect_ratio], unique: true
  end

  def down
    remove_index :crops, [:photo_id, :aspect_ratio]
    add_index :crops, :photo_id

    UNIQUE.each do |table, columns|
      columns.each do |column|
        remove_index table, column
        add_index table, column if table == :parks
      end
    end
  end

  private

  # Two requests from the crop editor can both miss a photo's crop for an aspect
  # ratio and both create one. Nothing references a crop by id, so unlike the
  # tables below the extras can simply go. The one kept is the one edited last:
  # edits land on whichever row the lookup finds, and that's the row the site has
  # been rendering.
  def remove_duplicate_crops!
    say_with_time 'Removing duplicate crops' do
      delete(<<~SQL)
        DELETE FROM crops WHERE id IN (
          SELECT id FROM (
            SELECT id, ROW_NUMBER() OVER (
              PARTITION BY photo_id, aspect_ratio ORDER BY updated_at DESC, id DESC
            ) AS position
            FROM crops
            WHERE photo_id IS NOT NULL AND aspect_ratio IS NOT NULL
          ) ranked
          WHERE position > 1
        )
      SQL
    end
  end

  # Duplicates in the other tables have to be merged by hand (photos point at one
  # of them), so the migration stops and says which, rather than picking a winner.
  def abort_on_duplicates!
    checks = UNIQUE.flat_map { |table, columns| columns.map { |column| [table, [column]] } } + [[:crops, [:photo_id, :aspect_ratio]]]
    found = checks.filter_map do |table, columns|
      cols = columns.join(', ')
      rows = select_rows("SELECT #{cols}, COUNT(*) FROM #{table} WHERE #{columns.map { |c| "#{c} IS NOT NULL" }.join(' AND ')} GROUP BY #{cols} HAVING COUNT(*) > 1 LIMIT 10")
      "#{table}(#{cols}): #{rows.map { |r| r[0...-1].join('/') }.join(', ')}" if rows.any?
    end
    raise "Merge these duplicates before adding unique indexes:\n#{found.join("\n")}" if found.any?
  end
end
