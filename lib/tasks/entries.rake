namespace :entries do
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

