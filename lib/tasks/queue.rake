namespace :queue do
  desc 'Publish the first entry in the queue'
  task :publish => [:environment] do
    if Time.now - Entry.published.first.published_at < 1.hour
      puts 'Last entry was published less than an hour ago. Aborting.'
    else
      entry = Entry.queued.first
      if entry.nil?
        puts 'There are no posts in the queue.'
      elsif entry.publish
        puts "Entry \"#{entry.title}\" published successfully."
      else
        puts 'Queued entry failed to publish.'
      end
    end
  end
end
