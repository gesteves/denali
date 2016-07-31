task :export => ['export:twitter', 'export:tumblr', 'export:facebook', 'export:flickr', 'export:pinterest']

namespace :export do
  task :twitter => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        entry.enqueue_twitter
        puts "Entry \"#{entry.title}\" queued for export to Twitter."
      end
    end
  end

  task :tumblr => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        entry.enqueue_tumblr
        puts "Entry \"#{entry.title}\" queued for export to Tumblr."
      end
    end
  end

  task :facebook => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        entry.enqueue_facebook
        puts "Entry \"#{entry.title}\" queued for export to Facebook."
      end
    end
  end

  task :flickr => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        entry.enqueue_flickr
        puts "Entry \"#{entry.title}\" queued for export to Flickr."
      end
    end
  end

  task :pinterest => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        entry.enqueue_pinterest
        puts "Entry \"#{entry.title}\" queued for export to Pinterest."
      end
    end
  end

  task :slack => [:environment] do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        entry.enqueue_slack
        puts "Entry \"#{entry.title}\" queued for export to Slack."
      end
    end
  end
end
