namespace :queue do
  desc 'Publish the first entry in the queue'
  task :publish => [:environment] do
    entry = Entry.queued.first
    if entry.nil?
      puts 'There are no posts in the queue.'
    elsif entry.publish
      puts "Entry \"#{entry.title}\" published successfully."
    else
      puts 'Queued entry failed to publish.'
    end
  end

  task :fix => [:environment] do
    Entry.published.where('position is not null').each do |entry|
      entry.remove_from_list
      entry.save
      puts "Published entry #{entry.id} updated with position #{entry.position}"
    end
    Entry.queued.each_with_index do |entry, index|
      entry.position = index + 1
      entry.save
      puts "Queued entry #{entry.id} updated witn position #{entry.position}"
    end
  end
end
