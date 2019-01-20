namespace :cloudfront do
  desc "Invalidates entry in CloudFront"
  task :invalidate => :environment do
    client = Aws::CloudFront::Client.new(access_key_id: ENV['aws_access_key_id'], secret_access_key: ENV['aws_secret_access_key'], region: ENV['s3_region'])
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      if entry.present?
        paths = [entry.permalink_path, entry.amp_path].compact
        quantity = paths.size
        response = client.create_invalidation({
          distribution_id: ENV['aws_cloudfront_distribution_id'],
          invalidation_batch: {
            paths: {
              quantity: quantity,
              items: paths,
            },
            caller_reference: Time.current.to_i.to_s,
          },
        })
        puts "Invalidation request sent for the following #{quantity} paths: #{paths.join(', ')}"
      else
        puts 'That entry wasn\'t found.'
      end
    elsif ENV['ENTRY_IDS'].present?
      entry_ids = ENV['ENTRY_IDS'].split(',').map(&:to_i)
      entries = Entry.where(id: entry_ids)
      paths = entries.map { |e| [e.permalink_path, e.amp_path] }.flatten.compact
      quantity = paths.size
      response = client.create_invalidation({
        distribution_id: ENV['aws_cloudfront_distribution_id'],
        invalidation_batch: {
          paths: {
            quantity: quantity,
            items: paths,
          },
          caller_reference: Time.current.to_i.to_s,
        },
      })
      puts "Invalidation request sent for the following #{quantity} paths: #{paths.join(', ')}"
    elsif ENV['COUNT'].present?
      count = ENV['COUNT'].to_i
      paths = Entry.published.limit(count).map { |e| [e.permalink_path, e.amp_path] }.flatten.compact
      quantity = paths.size
      response = client.create_invalidation({
        distribution_id: ENV['aws_cloudfront_distribution_id'],
        invalidation_batch: {
          paths: {
            quantity: quantity,
            items: paths,
          },
          caller_reference: Time.current.to_i.to_s,
        },
      })
      puts "Invalidation request sent for the following #{quantity} paths: #{paths.join(', ')}"
    elsif ENV['PATHS'].present?
      paths = ENV['PATHS'].split(',')
      quantity = paths.size
      response = client.create_invalidation({
        distribution_id: ENV['aws_cloudfront_distribution_id'],
        invalidation_batch: {
          paths: {
            quantity: quantity,
            items: paths,
          },
          caller_reference: Time.current.to_i.to_s,
        },
      })
      puts "Invalidation request sent for the following #{quantity} paths: #{paths.join(', ')}"
    else
      puts 'Please specify `ENTRY_ID` or `ENTRY_IDS` or `COUNT` or `PATHS`.'
    end
  end
end
