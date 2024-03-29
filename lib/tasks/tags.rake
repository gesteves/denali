namespace :tags do
  desc 'Update tags for all entries'
  task :update_all => :environment do
    Entry.find_each do |entry|
      puts "Updating tags for entry #{entry.permalink_url}"
      entry.update_tags
    end
    Blog.first.purge_from_cdn
  end
end
