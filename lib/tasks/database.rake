require 'aws-sdk-s3'

namespace :database do
  desc 'Create a database backup and upload to S3'
  task :backup => :environment do
    puts "Starting database backup..."
    DatabaseBackupJob.perform_inline
    puts "Backup complete!"
  end

  desc 'Download the most recent database backup from S3'
  task :download => :environment do
    if ENV['DB_BACKUP_BUCKET'].blank?
      puts "Error: DB_BACKUP_BUCKET environment variable is not set"
      exit 1
    end

    begin
      puts "Connecting to S3 bucket: #{ENV['DB_BACKUP_BUCKET']}"
      s3_client = Aws::S3::Client.new(
        region: ENV['AWS_REGION'] || 'us-east-1'
      )

      # List all .dump files in the bucket
      response = s3_client.list_objects_v2(
        bucket: ENV['DB_BACKUP_BUCKET'],
        prefix: 'denali_backup_'
      )

      if response.contents.empty?
        puts "No backup files found in bucket"
        exit 1
      end

      # Find the most recent backup
      most_recent = response.contents
        .select { |obj| obj.key.end_with?('.dump') }
        .max_by(&:last_modified)

      if most_recent.nil?
        puts "No .dump files found in bucket"
        exit 1
      end

      puts "Most recent backup: #{most_recent.key}"
      puts "Last modified: #{most_recent.last_modified}"
      puts "Size: #{(most_recent.size / 1024.0 / 1024.0).round(2)} MB"

      # Download the file to project root (accessible from host in Docker)
      download_path = Rails.root.join(most_recent.key)
      puts "\nDownloading to: #{download_path}"

      File.open(download_path, 'wb') do |file|
        s3_client.get_object(
          bucket: ENV['DB_BACKUP_BUCKET'],
          key: most_recent.key
        ) do |chunk|
          file.write(chunk)
        end
      end

      puts "Download complete!"
      puts "\nTo restore this backup, run:"
      puts "  pg_restore -d database_name #{download_path}"
    rescue Aws::S3::Errors::ServiceError => e
      puts "AWS S3 Error: #{e.message}"
      exit 1
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end
  end
end
