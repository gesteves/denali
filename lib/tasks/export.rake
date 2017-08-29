task :export => ['export:twitter', 'export:tumblr', 'export:facebook', 'export:flickr', 'export:pinterest', 'export:instagram']

namespace :export do
  task :twitter => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        TwitterJob.perform_later(entry)
        puts "Entry \"#{entry.title}\" queued for export to Twitter."
      end
    end
  end

  task :tumblr => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        TumblrJob.perform_later(entry)
        puts "Entry \"#{entry.title}\" queued for export to Tumblr."
      end
    end
  end

  task :facebook => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        FacebookJob.perform_later(entry)
        puts "Entry \"#{entry.title}\" queued for export to Facebook."
      end
    end
  end

  task :instagram => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        InstagramJob.perform_later(entry)
        puts "Entry \"#{entry.title}\" queued for export to Instagram."
      end
    end
  end

  task :flickr => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        FlickrJob.perform_later(entry)
        puts "Entry \"#{entry.title}\" queued for export to Flickr."
      end
    end
  end

  task :pinterest => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        PinterestJob.perform_later(entry)
        puts "Entry \"#{entry.title}\" queued for export to Pinterest."
      end
    end
  end

  task :buffer => [:twitter, :facebook, :instagram]
end
