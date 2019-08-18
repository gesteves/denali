namespace :tumblr do
  task :export => [:environment] do
    last = Entry.find(2689)
    entries = Entry.where('status = ? AND published_at > ?', 'published', last.published_at).tagged_with(["Wyoming", "Montana", "Mount Rainier National Park"], any: true).order('published_at ASC')
    entries.each do |e|
      TumblrWorker.new.perform(e.id, true)
      puts "Exported entry #{e.id}: #{e.plain_title}"
    end
  end
end
