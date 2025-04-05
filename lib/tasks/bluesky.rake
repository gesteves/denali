namespace :bluesky do
  desc "Change post_to_bluesky to true"
  task update_post_to_bluesky: :environment do
    tags = Array(ENV["TAGS"].split(",").map(&:strip))
    photoblog = Blog.first
    entries = photoblog.entries.tagged_with(tags)

    if ENV["DRY_RUN"].present?
      puts "DRY RUN: #{entries.size} entries will be updated"
    else
      puts "Updating #{entries.size} entries"
      entries.update_all(post_to_bluesky: true)
    end
  end
end
