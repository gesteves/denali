require 'rails_helper'

RSpec.describe StandardSiteJob, type: :worker do
  let(:social_account) { create(:social_account, provider: 'bluesky') }
  let(:blog) { create(:blog, standard_site_social_account: social_account) }
  let(:entry) { create(:entry, :published, blog: blog) }
  let(:service) { instance_double(StandardSite) }

  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    allow(Blog).to receive(:first).and_return(blog)
    allow(StandardSite).to receive(:from_blog).with(blog).and_return(service)
  end

  it 'syncs a document' do
    expect(service).to receive(:sync_document).with(entry.id)
    described_class.new.perform('sync_document', entry.id)
  end

  it 'deletes a document' do
    expect(service).to receive(:delete_document).with(entry.id)
    described_class.new.perform('delete_document', entry.id)
  end

  it 'syncs the publication' do
    expect(service).to receive(:sync_publication)
    described_class.new.perform('sync_publication')
  end

  it 'ignores an operation it does not know' do
    expect(Rails.logger).to receive(:warn).with(/unknown operation/)
    described_class.new.perform('nonsense')
  end

  it 'does nothing when the blog names no account' do
    allow(StandardSite).to receive(:from_blog).with(blog).and_return(nil)
    expect { described_class.new.perform('sync_publication') }.not_to raise_error
  end

  describe 'retries' do
    def retry_in(exception)
      described_class.sidekiq_retry_in_block.call(1, exception, {})
    end

    # ⚠️ sidekiq_retry_in in a subclass REPLACES ApplicationJob's block, so both branches have to
    # be restated here. ThreadsJob lost the UnprocessedPhotoError backoff exactly this way.
    it 'discards credentials the PDS refuses and still backs off an unprocessed photo' do
      expect(retry_in(Bluesky::AuthenticationError.new)).to eq(:discard)
      expect(retry_in(UnprocessedPhotoError.new)).to eq(2)
    end

    # The PDS says when it will take writes again, so waiting exactly that long beats spending
    # attempts on a limit that hasn't lifted.
    it 'waits as long as the PDS asked when it is rate limiting us' do
      limited = AtProto::RateLimitedError.new('slow down', retry_after: 420)

      expect(retry_in(limited)).to eq(420)
    end
  end
end
