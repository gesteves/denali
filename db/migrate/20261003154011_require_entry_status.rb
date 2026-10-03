# Every query and callback assumes an entry is a draft, queued or published; one
# with no status matches none of the scopes and silently vanishes from the admin.
#
# ⚠️ No column default. A new entry's status has to change from nil on create, or
# handle_status_change never runs and a draft keeps the queue position acts_as_list
# gave it.
class RequireEntryStatus < ActiveRecord::Migration[8.1]
  def up
    count = select_value("SELECT COUNT(*) FROM entries WHERE status IS NULL").to_i
    raise "#{count} entries have no status; set one before requiring it" if count.positive?

    change_column_null :entries, :status, false
  end

  def down
    change_column_null :entries, :status, true
  end
end
