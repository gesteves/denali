namespace :queue do
  desc 'Publish the first entry in the queue'
  task :publish => [:environment] do
    photoblog = Blog.first
    # Sometimes Heroku kicks off dupe scheduled jobs, publishing two posts by mistake
    if photoblog.entries.published.first.published_at >= 10.minutes.ago
      puts 'An entry was published less than 10 minutes ago!'
    elsif photoblog.time_to_publish_queued_entry?
      puts "Publishing queued entry..."
      photoblog.publish_queued_entry!
    else
      puts "It's not time to publish a queued entry."
    end
  end

  desc 'Fix the positions of the items in the queue'
  task :fix => [:environment] do
    puts "Old queue positions: #{Entry.queued.map(&:position).join(', ')}"
    Entry.queued.each_with_index do |entry, i|
      entry.position = i + 1
      entry.save
    end
    puts "New queue positions: #{Entry.queued.map(&:position).join(', ')}"
  end
end
