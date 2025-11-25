namespace :shares do
  desc 'Backfill shares_count columns based on last_shared_on timestamps'
  task :backfill => :environment do
    dry_run = ENV['DRY_RUN'] == 'true' || ENV['DRY_RUN'] == '1'

    platforms = {
      bluesky: { timestamp: :last_shared_on_bluesky_at, count: :bluesky_shares_count },
      mastodon: { timestamp: :last_shared_on_mastodon_at, count: :mastodon_shares_count },
      instagram: { timestamp: :last_shared_on_instagram_at, count: :instagram_shares_count },
      threads: { timestamp: :last_shared_on_threads_at, count: :threads_shares_count }
    }

    puts "DRY RUN!\n\n" if dry_run

    platforms.each do |platform, columns|
      entries = Entry.where.not(columns[:timestamp] => nil).where(columns[:count] => 0)
      count = entries.count

      if count == 0
        puts "#{platform.to_s.capitalize}: No entries to update"
        next
      end

      puts "#{platform.to_s.capitalize}: #{count} #{'entry'.pluralize(count)} to update"

      unless dry_run
        entries.update_all(columns[:count] => 1)
        puts "  ✓ Updated #{count} #{'entry'.pluralize(count)}"
      end
    end

    puts "\nDone!"
  end
end

