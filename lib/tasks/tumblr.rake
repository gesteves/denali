namespace :tumblr do
  task :export => [:environment] do
    entries = Entry.where(status: 'published').tagged_with(["Wyoming", "Montana", "Mount Rainier National Park"], any: true).order('published_at ASC')
    entries.each do |e|
      puts "Exporting entry #{e.id}: #{e.plain_title}"
      TumblrWorker.new.perform(e.id, true)
      sleep 1
    end
  end
end
