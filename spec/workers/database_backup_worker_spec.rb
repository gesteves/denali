require 'rails_helper'

RSpec.describe DatabaseBackupWorker, type: :worker do
  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DB_BACKUP_BUCKET').and_return('test-bucket')
    allow(ENV).to receive(:[]).with('DATABASE_URL').and_return('postgres://localhost/test')
    allow(ENV).to receive(:[]).with('AWS_REGION').and_return('us-east-1')
  end

  describe '#perform' do
    it 'returns early in non-production environment' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect_any_instance_of(described_class).not_to receive(:system)
      described_class.new.perform
    end

    it 'returns early when backup bucket is missing' do
      allow(ENV).to receive(:[]).with('DB_BACKUP_BUCKET').and_return(nil)
      expect_any_instance_of(described_class).not_to receive(:system)
      described_class.new.perform
    end

    it 'returns early when database URL is missing' do
      allow(ENV).to receive(:[]).with('DATABASE_URL').and_return(nil)
      expect_any_instance_of(described_class).not_to receive(:system)
      described_class.new.perform
    end

    it 'creates database dump and uploads to S3' do
      s3_client = instance_double(Aws::S3::Client)
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_client).to receive(:put_object)

      # Run a successful command to set $? to success state before stubbing system
      `true`

      # Mock successful pg_dump (return value is ignored, $? is checked)
      allow_any_instance_of(described_class).to receive(:system).and_return(true)

      # Mock file operations
      allow(File).to receive(:open).and_yield(StringIO.new('backup data'))
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:delete)

      expect(s3_client).to receive(:put_object).with(
        hash_including(bucket: 'test-bucket')
      )

      described_class.new.perform
    end

    it 'raises error when pg_dump fails' do
      # Run a failing command to set $? to failure state before stubbing system
      system('exit 1')

      allow_any_instance_of(described_class).to receive(:system).and_return(false)
      allow(File).to receive(:exist?).and_return(false)

      expect {
        described_class.new.perform
      }.to raise_error(/Database dump failed/)
    end
  end
end
