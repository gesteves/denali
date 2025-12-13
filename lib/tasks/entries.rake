namespace :entries do
  desc 'Hide entries from search engines if they cannot be shared on any social network, and vice versa'
  task :set_search_engine_setting => :environment do
    dry_run = ENV['DRY_RUN'] == 'true' || ENV['DRY_RUN'] == '1'

    puts "DRY RUN!\n\n" if dry_run

    # Entries that can be shared on at least one platform should be visible to search engines
    can_be_shared = Entry.where(
      'post_to_mastodon = ? OR post_to_bluesky = ? OR post_to_instagram = ? OR post_to_threads = ?',
      true, true, true, true
    )

    # Entries that cannot be shared on any platform should be hidden from search engines
    cannot_be_shared = Entry.where(
      post_to_mastodon: false,
      post_to_bluesky: false,
      post_to_instagram: false,
      post_to_threads: false
    )

    puts "Entries to set hide_from_search_engines = FALSE (can be shared): #{can_be_shared.count}"
    puts "Entries to set hide_from_search_engines = TRUE (cannot be shared): #{cannot_be_shared.count}"
    puts ""

    total = can_be_shared.count + cannot_be_shared.count

    if total == 0
      puts "No entries need updating."
      return
    end

    hidden_count = 0
    shown_count = 0

    unless dry_run
      puts "Updating entries...\n\n"

      can_be_shared.find_each do |entry|
        entry.update(hide_from_search_engines: false)
        puts "  SHOW: #{entry.title} - #{entry.permalink_url}"
        shown_count += 1
      end

      cannot_be_shared.find_each do |entry|
        entry.update(hide_from_search_engines: true)
        puts "  HIDE: #{entry.title} - #{entry.permalink_url}"
        hidden_count += 1
      end

      puts "\nSummary:"
      puts "  #{hidden_count} #{'entry'.pluralize(hidden_count)} set to hide_from_search_engines = true"
      puts "  #{shown_count} #{'entry'.pluralize(shown_count)} set to hide_from_search_engines = false"
    end
  end

  desc 'Disable post_on* attributes for entries tagged with a specific tag'
  task :disable_sharing => :environment do
    tag = ENV['TAG']
    dry_run = ENV['DRY_RUN'] == 'true' || ENV['DRY_RUN'] == '1'

    if tag.blank?
      puts "Error: TAG environment variable is required"
      puts "Usage: TAG=tag_name [DRY_RUN=true] rake entries:disable_sharing"
      exit 1
    end

    entries = Entry.tagged_with(tag).where(
      'post_to_mastodon = ? OR post_to_bluesky = ? OR post_to_instagram = ? OR post_to_threads = ?',
      true, true, true, true
    )
    count = entries.count

    if count == 0
      puts "No entries found tagged with '#{tag}' that have at least one sharing setting enabled"
      return
    end

    puts "DRY RUN!\n\n" if dry_run
    puts "Entries:"

    entries.each do |entry|
      puts "  #{entry.title} - #{entry.permalink_url}"
    end

    puts "\nFound #{count} #{'entry'.pluralize(count)} tagged with '#{tag}' with at least one sharing setting enabled."

    if !dry_run
      puts "\nUpdating #{count} #{'entry'.pluralize(count)}..."

      updated_count = 0
      entries.find_each do |entry|
        entry.update(
          post_to_mastodon: false,
          post_to_bluesky: false,
          post_to_instagram: false,
          post_to_threads: false
        )
        updated_count += 1
      end

      puts "\nSuccessfully updated #{updated_count} #{'entry'.pluralize(updated_count)}"
    end
  end
end

