namespace :tags do
  desc 'Update tags for all entries'
  task :update_all => :environment do
    Entry.find_each do |entry|
      puts "Updating tags for entry #{entry.permalink_url}"
      entry.update_tags
    end
  end

  desc 'Remove tag customizations that only have Instagram hashtags'
  task :remove_instagram_hashtags => :environment do
    TagCustomization.where.not(instagram_hashtags: nil).where(flickr_groups: [nil, ''], flickr_albums: [nil, '']).destroy_all
  end
end
