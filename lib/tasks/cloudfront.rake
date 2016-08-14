namespace :cloudfront do
  desc "Invalidates entry in CloudFront"
  task :invalidate => :environment do
    invalidator = CloudfrontInvalidator.new(ENV['aws_access_key_id'], ENV['aws_secret_access_key'], ENV['aws_cloudfront_distribution_id'])
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        invalidator.invalidate(entry.permalink_path)
        puts "Invalidation request for \"#{entry.title}\" has been sent."
      else
        puts 'That entry wasn\'t found.'
      end
    elsif ENV['COUNT'].present?
      count = ENV['COUNT'].to_i
      entries = Entry.published.limit(count).map { |e| e.permalink_path }
      invalidator.invalidate(entries)
      puts "Invalidation request for the most recent #{pluralize(count, 'entry')} has been sent."
    else
      puts 'Please specify an `ENTRY_ID` or a `COUNT`.'
    end
  end
end
