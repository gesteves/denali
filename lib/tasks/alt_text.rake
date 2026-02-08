namespace :alt_text do
  desc "Generate alt text for a specific entry"
  task update_entry: :environment do
    return if ENV['ENTRY_ID'].blank?
    entry = Entry.find(ENV['ENTRY_ID'])
    entry.photos.each do |photo|
      puts "Updating alt text for photo #{photo.id}"
      AltTextJob.perform_async(photo.id)
    end
  end

  desc "Generate alt text for all photos with specific tags"
  task update_tags: :environment do
    return if ENV["TAGS"].blank?
    tags = Array(ENV["TAGS"].split(",").map(&:strip))
    photoblog = Blog.first
    entries = photoblog.entries.tagged_with(tags)

    if ENV["DRY_RUN"].present?
      puts "DRY RUN: #{entries.size} entries will be updated"
    else
      puts "Updating #{entries.size} entries"
      entries.each do |entry|
        puts "Updating alt text for entry #{entry.permalink_url}"
        entry.photos.each do |photo|
          AltTextJob.perform_async(photo.id)
        end
      end
    end
  end
end
