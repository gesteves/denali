# lib/tasks/update_shared_timestamps.rake

namespace :entries do
  desc "Set last_shared_on_* timestamps to the value of the published_at column"
  task update_shared_timestamps: :environment do
    Entry.find_each do |entry|
      entry.update_columns(
        last_shared_on_instagram_at: entry.published_at,
        last_shared_on_bluesky_at: entry.published_at,
        last_shared_on_mastodon_at: entry.published_at
      )
      puts "Updated timestamps for entry #{entry.id}"
    end
    puts "Timestamps updated for all entries."
  end
end
