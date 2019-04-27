namespace :amp do
  desc "Validates AMP for all entries"
  task :validate_all => :environment do
    Entry.find_each do |entry|
      AmpValidationWorker.perform_async(entry.id)
    end
  end
end
