namespace :tags do
  desc "Refreshes an entry's tags"
  task :update => :environment do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      entry.update_tags if entry.present?
    else
      puts 'Please specify `ENTRY_ID`.'
    end
  end

  desc "Refreshes tags for all entries"
  task :update_all => :environment do
    Entry.find_each do |entry|
      entry.update_tags
    end
  end
end
