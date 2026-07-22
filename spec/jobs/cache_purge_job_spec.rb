require 'rails_helper'

RSpec.describe CachePurgeJob, type: :worker do
  let(:purge_url) { 'https://api.cloudflare.com/client/v4/zones/zone123/purge_cache' }

  def stub_purge(body: { 'success' => true, 'errors' => [] }, status: 200)
    stub_request(:post, purge_url).to_return(status: status, body: body.to_json)
  end

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CLOUDFLARE_ZONE_ID').and_return('zone123')
    allow(ENV).to receive(:[]).with('CLOUDFLARE_API_TOKEN').and_return('token456')
  end

  describe '#perform' do
    it 'purges the given tags' do
      stub_purge

      described_class.new.perform('entry-1', 'entries')

      expect(WebMock).to have_requested(:post, purge_url)
        .with(body: { tags: ['entry-1', 'entries'] }.to_json,
              headers: { 'Authorization' => 'Bearer token456', 'Content-Type' => 'application/json' })
    end

    it 'returns early in non-production environments' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect(HTTParty).not_to receive(:post)
      described_class.new.perform('entries')
    end

    it 'returns early when the zone is missing' do
      allow(ENV).to receive(:[]).with('CLOUDFLARE_ZONE_ID').and_return(nil)
      expect(HTTParty).not_to receive(:post)
      described_class.new.perform('entries')
    end

    it 'returns early when the token is missing' do
      allow(ENV).to receive(:[]).with('CLOUDFLARE_API_TOKEN').and_return(nil)
      expect(HTTParty).not_to receive(:post)
      described_class.new.perform('entries')
    end

    it 'does nothing when given no tags' do
      expect(HTTParty).not_to receive(:post)
      described_class.new.perform
    end

    it 'deduplicates tags' do
      stub_purge

      described_class.new.perform('entries', 'entries', nil)

      expect(WebMock).to have_requested(:post, purge_url).with(body: { tags: ['entries'] }.to_json)
    end

    it 'splits large tag sets across requests' do
      stub_purge
      tags = (1..45).map { |i| "entry-#{i}" }

      described_class.new.perform(*tags)

      expect(WebMock).to have_requested(:post, purge_url).twice
      expect(WebMock).to have_requested(:post, purge_url).with(body: { tags: tags.first(30) }.to_json)
      expect(WebMock).to have_requested(:post, purge_url).with(body: { tags: tags.last(15) }.to_json)
    end

    it 'raises when Cloudflare reports failure, so Sidekiq retries' do
      stub_purge(body: { 'success' => false, 'errors' => [{ 'message' => 'Invalid zone' }] })

      expect {
        described_class.new.perform('entries')
      }.to raise_error(/Invalid zone/)
    end

    it 'raises on an HTTP error' do
      stub_purge(status: 403, body: { 'success' => false, 'errors' => [{ 'message' => 'Forbidden' }] })

      expect {
        described_class.new.perform('entries')
      }.to raise_error(/Forbidden/)
    end
  end

  describe '.enqueue' do
    # The test environment uses a null store, which never reports an existing
    # key, so the debounce can only be exercised against a real store.
    around do |example|
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original
    end

    it 'schedules a purge on the trailing edge of the window' do
      expect(described_class).to receive(:perform_in).with(described_class::DEBOUNCE, 'entries')
      described_class.enqueue('entries')
    end

    it 'collapses a burst of identical purges into one' do
      expect(described_class).to receive(:perform_in).once

      5.times { described_class.enqueue('entry-1', 'entries') }
    end

    it 'collapses regardless of the order the tags arrive in' do
      expect(described_class).to receive(:perform_in).once

      described_class.enqueue('entry-1', 'entries')
      described_class.enqueue('entries', 'entry-1')
    end

    it 'does not collapse purges for different tag sets' do
      expect(described_class).to receive(:perform_in).twice

      described_class.enqueue('entry-1')
      described_class.enqueue('entry-2')
    end

    it 'purges again once the window has passed' do
      expect(described_class).to receive(:perform_in).twice

      described_class.enqueue('entries')
      travel(described_class::DEBOUNCE + 1.second) do
        described_class.enqueue('entries')
      end
    end

    it 'does nothing when given no tags' do
      expect(described_class).not_to receive(:perform_in)
      described_class.enqueue
    end
  end
end
