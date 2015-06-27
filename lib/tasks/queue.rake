namespace :queue do
  desc 'Publish the first entry in the queue'
  task :publish => [:environment] do
    entry = Entry.queued.first
    if entry.nil?
      puts 'There are no posts in the queue.'
    elsif entry.publish
      TwitterJob.perform_later(entry) if entry.post_to_twitter
      TumblrJob.perform_later(entry) if entry.post_to_tumblr
      BufferJob.perform_later(entry) if entry.post_to_facebook
      YoJob.perform_later(entry) if entry.send_yo
      puts "Entry \"#{entry.title}\" published successfully."
    else
      puts 'Queued entry failed to publish.'
    end
  end
end
