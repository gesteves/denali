namespace :flickr do
  desc "Adds the given photo to its corresponding groups"
  task :groups => :environment do
    if ENV['ENTRY_ID'].present? && ENV['PHOTO_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      photo_id = ENV['PHOTO_ID']
      if entry.present?
        entry.flickr_groups.each do |group_id|
          FlickrGroupWorker.perform_async(photo_id, group_id)
        end
      end
    end
  end
end
