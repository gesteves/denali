namespace :queue do
  desc 'Publish the first entry in the queue'
  task :publish => [:environment] do
    photoblog = Blog.first
    # Sometimes Heroku kicks off dupe scheduled jobs, publishing two posts by mistake,
    # so only attempt to publish a queued entry if another one hasn't been published in the last 10 minutes
    photoblog.publish_queued_entry! unless photoblog.entries.published.first.published_at >= 10.minutes.ago
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
