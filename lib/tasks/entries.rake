namespace :entries do
  desc "Update fields for entries not posted on Tumblr"
  task update_fields: :environment do
    # Fetching entries that are not posted on Tumblr
    entries_to_update = Entry.where.not(id: Entry.posted_on_tumblr.pluck(:id))

    # Updating the fields
    entries_to_update.find_each do |entry|
      entry.update(
        post_to_instagram: false,
        post_to_tumblr: false,
        post_to_mastodon: false,
        post_to_bluesky: false
      )
    end

    puts "Updated #{entries_to_update.count} entries"
  end
end
