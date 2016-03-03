namespace :colors do
  desc 'Set colors for all queued entries'
  task :queued => [:environment] do
    Entry.queued.find_each do |entry|
      entry.photos.each do |photo|
        DominantColorJob.perform_later(photo)
      end
    end
  end

  task :published => [:environment] do
    Entry.published.find_each do |entry|
      entry.photos.each do |photo|
        DominantColorJob.perform_later(photo)
      end
    end
  end
end
