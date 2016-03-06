namespace :colors do
  desc 'Set colors for all queued entries'
  task :queued => [:environment] do
    Entry.queued.each do |entry|
      entry.photos.each do |photo|
        DominantColorJob.perform_later(photo)
      end
    end
  end

  task :entry => [:environment] do
    entry = Entry.find(ENV['ENTRY_ID'])
    if entry.present?
      entry.photos.each do |photo|
        DominantColorJob.perform_later(photo)
      end
    end
  end

  task :all => [:environment] do
    Photo.where('dominant_color is ?', nil).each do |photo|
      DominantColorJob.perform_later(photo)
    end
  end
end
