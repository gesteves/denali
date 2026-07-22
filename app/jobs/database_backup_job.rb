require 'aws-sdk-s3'

class DatabaseBackupJob < ApplicationJob
  sidekiq_options retry_for: 1.day

  def perform
    return unless Rails.env.production?
    return if ENV['DB_BACKUP_BUCKET'].blank?
    return if ENV['DATABASE_URL'].blank?

    logger.info "[Database Backup] Starting database backup"

    begin
      # Generate backup filename with timestamp
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      filename = "denali_backup_#{timestamp}.dump"
      filepath = Rails.root.join('tmp', filename)

      # Create database dump
      logger.info "[Database Backup] Creating database dump: #{filename}"
      system("pg_dump -Fc --no-acl --no-owner -f #{filepath} #{ENV['DATABASE_URL']}")

      unless $?.success?
        raise "Database dump failed with exit code #{$?.exitstatus}"
      end

      # Upload to R2 via the S3-compatible API. The checksum options are
      # required because aws-sdk-s3 >= 1.178 sends CRC32 checksums by default,
      # which R2 doesn't fully support.
      logger.info "[Database Backup] Uploading to R2 bucket: #{ENV['DB_BACKUP_BUCKET']}"
      s3_client = Aws::S3::Client.new(
        endpoint: ENV['R2_ENDPOINT'],
        region: 'auto',
        access_key_id: ENV['R2_ACCESS_KEY_ID'],
        secret_access_key: ENV['R2_SECRET_ACCESS_KEY'],
        request_checksum_calculation: 'when_required',
        response_checksum_validation: 'when_required'
      )

      File.open(filepath, 'rb') do |file|
        s3_client.put_object(
          bucket: ENV['DB_BACKUP_BUCKET'],
          key: filename,
          body: file
        )
      end

      logger.info "[Database Backup] Backup uploaded successfully: #{filename}"
    ensure
      # Clean up local file
      if filepath && File.exist?(filepath)
        File.delete(filepath)
        logger.info "[Database Backup] Cleaned up local backup file"
      end
    end
  end
end
