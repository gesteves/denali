# Active Record Encryption configuration
# In production, use environment variables
# In development/test, use static keys for convenience

if Rails.env.test? || Rails.env.development?
  Rails.application.config.active_record.encryption.primary_key = 'test_primary_key_that_is_at_least_32_characters'
  Rails.application.config.active_record.encryption.deterministic_key = 'test_deterministic_key_at_least_32_chars'
  Rails.application.config.active_record.encryption.key_derivation_salt = 'test_key_derivation_salt_at_least_32_chars'
else
  Rails.application.config.active_record.encryption.primary_key = ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY']
  Rails.application.config.active_record.encryption.deterministic_key = ENV['ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY']
  Rails.application.config.active_record.encryption.key_derivation_salt = ENV['ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT']
end
