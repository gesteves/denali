require 'rails_helper'

RSpec.describe ThreadsJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let!(:threads_account) { create(:social_account, :threads, user: user) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('THREADS_APP_ID').and_return('app_id')
    allow(ENV).to receive(:[]).with('THREADS_APP_SECRET').and_return('app_secret')
  end

  describe '#perform' do
    it 'returns early in non-production environment' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect(Threads).not_to receive(:new)
      described_class.new.perform(entry.id, 'Test caption')
    end

    it 'returns early when credentials are missing' do
      allow(ENV).to receive(:[]).with('THREADS_APP_ID').and_return(nil)
      expect(Threads).not_to receive(:new)
      described_class.new.perform(entry.id, 'Test caption')
    end

    it 'returns early for non-photo entries' do
      text_entry = create(:entry, :published, blog: blog, user: user)
      expect(Threads).not_to receive(:new)
      described_class.new.perform(text_entry.id, 'Test caption')
    end

    it 'returns early when user has no threads account' do
      threads_account.destroy
      expect(Threads).not_to receive(:new)
      described_class.new.perform(entry.id, 'Test caption')
    end

    # See instagram_job_spec.rb for the steps they share (MetaShareJob); these are what's Threads'.
    context 'posting' do
      let(:client) { instance_double(Threads) }

      around do |example|
        original = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
        example.run
      ensure
        Rails.cache = original
      end

      before do
        allow(Threads).to receive(:new).and_return(client)
        allow_any_instance_of(Photo).to receive(:warm_cache)
        allow_any_instance_of(Entry).to receive(:threads_topic).and_return('Photography')
        allow_any_instance_of(Photo).to receive(:threads_location_id).and_return('loc_1')
        allow(client).to receive(:create_media_container).and_return('c1')
        allow(client).to receive(:publish_container).with('c1').and_return('id' => 't1')
      end

      def attempt(text = 'Test caption')
        job = described_class.new
        job.jid = 'jid-1'
        job.perform(entry.id, text)
      end

      it 'posts with the topic and location, once Meta has processed the container' do
        expect(Threads).to receive(:new).with(app_id: 'app_id', app_secret: 'app_secret', social_account: threads_account)

        expect { attempt }.to raise_error(MetaContainerPendingError)
        expect(client).to have_received(:create_media_container)
          .with(hash_including(caption: 'Test caption', topic_tag: 'Photography', location_id: 'loc_1'))

        allow(client).to receive(:container_status).with('c1').and_return('code' => 'FINISHED', 'error' => nil)
        attempt

        expect(client).to have_received(:publish_container).once
        entry.reload
        expect(entry.last_shared_on_threads_at).not_to be_nil
        expect(entry.threads_shares_count).to eq(1)
      end

      it "refuses a caption over Threads' 500 characters without calling Threads" do
        expect(Threads).not_to receive(:new)

        expect { attempt('x' * 501) }.to raise_error(MetaCaptionTooLongError)
      end
    end
  end
end
