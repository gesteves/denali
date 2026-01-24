require 'rails_helper'

RSpec.describe CloudfrontInvalidationWorker, type: :worker do
  describe '#perform' do
    let(:cloudfront_client) { instance_double(Aws::CloudFront::Client) }

    before do
      allow(Aws::CloudFront::Client).to receive(:new).and_return(cloudfront_client)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('CACHE_TTL').and_return('86400')
      allow(ENV).to receive(:[]).with('AWS_ACCESS_KEY_ID').and_return('key')
      allow(ENV).to receive(:[]).with('AWS_SECRET_ACCESS_KEY').and_return('secret')
      allow(ENV).to receive(:[]).with('S3_REGION').and_return('us-east-1')
      allow(ENV).to receive(:[]).with('AWS_CLOUDFRONT_DISTRIBUTION_ID').and_return('E12345')
    end

    it 'creates invalidation request for given paths' do
      paths = ['/path1', '/path2']

      expect(cloudfront_client).to receive(:create_invalidation).with(
        hash_including(
          distribution_id: 'E12345',
          invalidation_batch: hash_including(
            paths: hash_including(
              quantity: 2,
              items: paths
            )
          )
        )
      )

      described_class.new.perform(paths)
    end

    it 'filters out invalid paths' do
      paths = ['/valid', 'invalid-no-slash', '', nil, '/another-valid']

      expect(cloudfront_client).to receive(:create_invalidation).with(
        hash_including(
          invalidation_batch: hash_including(
            paths: hash_including(
              quantity: 2,
              items: ['/another-valid', '/valid']
            )
          )
        )
      )

      described_class.new.perform(paths)
    end

    it 'batches paths into groups of 15 and enqueues separate jobs' do
      paths = (1..20).map { |i| "/path#{i}" }

      expect(CloudfrontInvalidationWorker).to receive(:perform_async).twice

      described_class.new.perform(paths)
    end

    context 'with low CACHE_TTL' do
      before do
        allow(ENV).to receive(:[]).with('CACHE_TTL').and_return('3600')
      end

      it 'returns early without creating invalidation' do
        expect(cloudfront_client).not_to receive(:create_invalidation)
        described_class.new.perform(['/path'])
      end
    end

    context 'in non-production environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'returns early without creating invalidation' do
        expect(cloudfront_client).not_to receive(:create_invalidation)
        described_class.new.perform(['/path'])
      end
    end
  end
end
