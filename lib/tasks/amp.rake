namespace :amp do
  desc "Invalidates entry in AMP Cache"
  task :flush => :environment do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        AmpCacheJob.perform_later(entry)
        puts "AMP Cache update request sent"
      else
        puts 'That entry wasn\'t found.'
      end
    elsif ENV['ENTRY_IDS'].present?
      entry_ids = ENV['ENTRY_IDS'].split(',').map(&:to_i)
      entries = Entry.where(id: entry_ids)
      entries.map { |entry| AmpCacheJob.perform_later(entry) }
      puts "AMP Cache update requests sent"
    elsif ENV['COUNT'].present?
      count = ENV['COUNT'].to_i
      entries = Entry.published.limit(count)
      entries.map { |entry| AmpCacheJob.perform_later(entry) }
      puts "AMP Cache update requests sent"
    else
      puts 'Please specify `ENTRY_ID` or `ENTRY_IDS` or `COUNT`.'
    end
  end

  desc "Invalidates all published entries in AMP Cache"
  task :flush_all => :environment do
    Entry.published.map { |entry| AmpCacheJob.perform_later(entry) }
  end
end
