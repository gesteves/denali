namespace :queue do
  desc 'Publish the first entry in the queue'
  task :publish => [:environment] do
    if Entry.queue_has_published_today?
      puts 'An entry was already published today!'
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
