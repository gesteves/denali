namespace :requestbin do
  desc "Post to requestbin"
  task :post => :environment do
    entry = Entry.published.last
    if entry.present?
      RequestbinJob.perform_later(entry)
      puts "Entry \"#{entry.title}\" queued for post to Requestbin."
    end
  end
end
