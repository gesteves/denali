namespace :entries do
  desc "Update last_shared_on_* timestamps with conditions"
  task update_shared_timestamps: :environment do
    Entry.find_each do |entry|
      updates = {}

      # Set last_shared_on_instagram_at to nil if it's before November 1, 2016
      if entry.last_shared_on_instagram_at.present? && entry.last_shared_on_instagram_at < Date.new(2016, 11, 1)
        updates[:last_shared_on_instagram_at] = nil
      end

      # Set last_shared_on_mastodon_at to nil if it's before 2 weeks ago
      if entry.last_shared_on_mastodon_at.present? && entry.last_shared_on_mastodon_at < 2.weeks.ago
        updates[:last_shared_on_mastodon_at] = nil
      end

      # Set last_shared_on_bluesky_at to nil if it's before August 9, 2024
      if entry.last_shared_on_bluesky_at.present? && entry.last_shared_on_bluesky_at < Date.new(2024, 8, 9)
        updates[:last_shared_on_bluesky_at] = nil
      end

      # Only update if there are changes
      if updates.any?
        entry.update_columns(updates)
        puts "Updated timestamps for entry #{entry.id}: #{updates}"
      end
    end

    puts "Timestamps updated for all applicable entries."
  end
end
