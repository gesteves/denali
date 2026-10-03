# Cameras, lenses, films and parks put their names on the entries photographed
# with them, as tags. Renaming one retags every one of those entries, a save each,
# so it happens in a job once the rename has committed, not inside the admin's
# request and its transaction.
module RetagsEntries
  extend ActiveSupport::Concern

  included do
    after_commit :retag_entries_later, on: :update, if: :retag_entries?
  end

  def update_entry_tags
    Entry.where(id: photos.select(:entry_id)).find_each(&:update_tags)
  end

  private

  # Overridden by models whose tags come from more than the display name.
  def retag_entries?
    saved_change_to_display_name?
  end

  def retag_entries_later
    RetagEntriesJob.perform_async(self.class.name, id)
  end
end
