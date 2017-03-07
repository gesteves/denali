task :export => ['export:twitter', 'export:tumblr', 'export:facebook', 'export:flickr', 'export:pinterest']

namespace :export do
  task :twitter => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        BufferJob.perform_later(entry, 'twitter')
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
        BufferJob.perform_later(entry, 'facebook')
        puts "Entry \"#{entry.title}\" queued for export to Facebook."
      end
    end
  end

  task :instagram => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        BufferJob.perform_later(entry, 'instagram')
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

  task :slack => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        SlackIncomingWebhook.post_all(entry)
        puts "Entry \"#{entry.title}\" queued for export to Slack."
      end
    end
  end
end
