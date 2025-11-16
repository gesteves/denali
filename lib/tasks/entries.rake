namespace :entries do
  desc "Set last_shared_on_instagram_at and last_shared_on_threads_at to published_at for entries published in the last month"
  task update_recent_share_timestamps: :environment do
    one_month_ago = 1.month.ago
    entries = Entry.published.where("published_at >= ?", one_month_ago)

    if ENV["DRY_RUN"].present?
      puts "DRY RUN: #{entries.size} entries will be updated"
      entries.each do |entry|
        puts "  Entry #{entry.id}: Setting last_shared_on_instagram_at and last_shared_on_threads_at to #{entry.published_at}"
      end
    else
      puts "Updating #{entries.size} entries"
      updated_count = entries.update_all(
        "last_shared_on_instagram_at = published_at, last_shared_on_threads_at = published_at"
      )
      puts "Updated #{updated_count} entries"
    end
  end

  desc "Set post_to_instagram and post_to_threads to false for entries where post_to_bluesky is false"
  task sync_bluesky_posting_flags: :environment do
    entries = Entry.where(post_to_bluesky: false)

    if ENV["DRY_RUN"].present?
      puts "DRY RUN: #{entries.size} entries will be updated"
      entries.each do |entry|
        puts "  Entry #{entry.id}: Setting post_to_instagram and post_to_threads to false"
      end
    else
      puts "Updating #{entries.size} entries"
      updated_count = entries.update_all(
        "post_to_instagram = false, post_to_threads = false"
      )
      puts "Updated #{updated_count} entries"
    end
  end
end

