namespace :cloudfront do
  desc "Invalidates entry in CloudFront"
  task :invalidate => :environment do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        invalidator = CloudfrontInvalidator.new(ENV['aws_access_key_id'], ENV['aws_secret_access_key'], ENV['aws_cloudfront_distribution_id'])
        invalidator.invalidate(entry.permalink_path)
        puts "Invalidation request for \"#{entry.title}\" has been sent."
      else
        puts 'That entry wasn\'t found.'
      end
    else
      puts 'Please specify an ENTRY_ID.'
    end
  end
end
