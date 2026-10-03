require 'rails_helper'

RSpec.describe InstagramJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let!(:instagram_account) { create(:social_account, :instagram, user: user) }
  let(:client) { instance_double(Instagram) }

  around do |example|
    # The job keeps its progress between attempts in the cache, which the test environment doesn't.
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return('app_id')
    allow(ENV).to receive(:[]).with('INSTAGRAM_APP_SECRET').and_return('app_secret')
    allow(Instagram).to receive(:new).and_return(client)
    allow_any_instance_of(Photo).to receive(:warm_cache)
    allow_any_instance_of(Entry).to receive(:instagram_hashtags).and_return('#nature #photo')
    Sidekiq::Job.clear_all
  end

  # One attempt of the same job, as Sidekiq's retries make them: the same jid each time, so it
  # picks up where the last attempt stopped.
  def attempt(text = 'Test caption')
    job = described_class.new
    job.jid = 'jid-1'
    job.perform(entry.id, text)
  end

  def status(code, error = nil)
    { 'code' => code, 'error' => error }
  end

  describe '#perform' do
    it 'returns early in non-production environment' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect(Instagram).not_to receive(:new)
      attempt
    end

    it 'returns early when credentials are missing' do
      allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return(nil)
      expect(Instagram).not_to receive(:new)
      attempt
    end

    it 'returns early for non-photo entries' do
      text_entry = create(:entry, :published, blog: blog, user: user)
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(text_entry.id, 'Test caption')
    end

    it 'returns early when user has no connected Instagram account' do
      instagram_account.destroy
      expect(Instagram).not_to receive(:new)
      attempt
    end

    it 'initializes Instagram with the connected social account' do
      allow(client).to receive(:create_media_container).and_return('c1')

      expect(Instagram).to receive(:new).with(app_id: 'app_id', app_secret: 'app_secret', social_account: instagram_account)

      expect { attempt }.to raise_error(MetaContainerPendingError)
    end

    # The caption is checked before anything is made at Meta.
    it 'refuses a caption over the limit without calling Instagram' do
      expect(Instagram).not_to receive(:new)

      expect { attempt('x' * 2201) }.to raise_error(MetaCaptionTooLongError)
    end

    context 'with a single photo' do
      before do
        allow(client).to receive(:create_media_container).and_return('c1')
        allow(client).to receive(:publish_container).with('c1').and_return('id' => 'm1')
      end

      # Waiting is a retry a few seconds later, not a sleep that holds a Sidekiq thread.
      it 'creates the container and comes back for it later' do
        expect { attempt }.to raise_error(MetaContainerPendingError)

        expect(client).to have_received(:create_media_container).with(hash_including(caption: 'Test caption'))
        expect(entry.reload.instagram_shares_count).to eq(0)
      end

      it 'waits while Meta is still processing it' do
        expect { attempt }.to raise_error(MetaContainerPendingError)
        allow(client).to receive(:container_status).with('c1').and_return(status('IN_PROGRESS'))

        expect { attempt }.to raise_error(MetaContainerPendingError)
        expect(client).to have_received(:create_media_container).once
      end

      it 'publishes once Meta has processed it, and records the share' do
        expect { attempt }.to raise_error(MetaContainerPendingError)
        allow(client).to receive(:container_status).with('c1').and_return(status('FINISHED'))

        attempt

        expect(client).to have_received(:publish_container).once
        expect(entry.reload.instagram_shares_count).to eq(1)
        expect(InstagramCommentJob.jobs.map { |job| job['args'] }).to eq([[entry.id, 'm1']])
      end

      # A retry after a publish that went through used to make a new container and post again.
      it 'never publishes twice' do
        expect { attempt }.to raise_error(MetaContainerPendingError)
        allow(client).to receive(:container_status).with('c1').and_return(status('FINISHED'))
        allow(InstagramCommentJob).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)

        expect { attempt }.to raise_error(RedisClient::CannotConnectError)
        allow(InstagramCommentJob).to receive(:perform_async).and_call_original
        attempt

        expect(client).to have_received(:create_media_container).once
        expect(client).to have_received(:publish_container).once
        expect(entry.reload.instagram_shares_count).to eq(1)
        expect(InstagramCommentJob.jobs.size).to eq(1)
      end

      # The response to the publish that went through never arrived.
      it 'treats a container Meta says is published as published' do
        expect { attempt }.to raise_error(MetaContainerPendingError)
        allow(client).to receive(:container_status).with('c1').and_return(status('PUBLISHED'))

        attempt

        expect(client).not_to have_received(:publish_container)
        expect(entry.reload.instagram_shares_count).to eq(1)
        # Without the post's ID there's nothing to comment on.
        expect(InstagramCommentJob.jobs).to be_empty
      end

      it 'starts over with a new container when Meta fails one' do
        expect { attempt }.to raise_error(MetaContainerPendingError)
        allow(client).to receive(:container_status).with('c1').and_return(status('ERROR', 'Image could not be fetched'))

        expect { attempt }.to raise_error(MetaContainerPendingError)
        expect(client).to have_received(:create_media_container).twice
      end

      # An image Meta can't process fails the same way every time.
      it 'gives up after starting over twice' do
        expect { attempt }.to raise_error(MetaContainerPendingError)
        allow(client).to receive(:container_status).with('c1').and_return(status('EXPIRED'))
        2.times { expect { attempt }.to raise_error(MetaContainerPendingError) }

        expect { attempt }.to raise_error(MetaContainerFailedError, /EXPIRED/)
        expect(client).to have_received(:create_media_container).exactly(3).times
      end

      it "doesn't comment without hashtags" do
        allow_any_instance_of(Entry).to receive(:instagram_hashtags).and_return(nil)
        expect { attempt }.to raise_error(MetaContainerPendingError)
        allow(client).to receive(:container_status).with('c1').and_return(status('FINISHED'))

        attempt

        expect(InstagramCommentJob.jobs).to be_empty
      end
    end

    context 'with several photos' do
      before do
        create(:photo, entry: entry).tap { |p| attach_image_to_photo(p) }
        allow(client).to receive(:create_carousel_items).and_return(%w[i1 i2])
        allow(client).to receive(:create_carousel_container).and_return('carousel')
        allow(client).to receive(:publish_container).with('carousel').and_return('id' => 'm1')
      end

      it 'makes the carousel once its photos are processed, then publishes it' do
        expect { attempt }.to raise_error(MetaContainerPendingError)
        expect(client).to have_received(:create_carousel_items).with(an_instance_of(Array).and(have_attributes(size: 2)))

        allow(client).to receive(:container_status).with('i1').and_return(status('FINISHED'))
        allow(client).to receive(:container_status).with('i2').and_return(status('IN_PROGRESS'))
        expect { attempt }.to raise_error(MetaContainerPendingError)
        expect(client).not_to have_received(:create_carousel_container)

        allow(client).to receive(:container_status).with('i2').and_return(status('FINISHED'))
        expect { attempt }.to raise_error(MetaContainerPendingError)
        expect(client).to have_received(:create_carousel_container).with(hash_including(children: %w[i1 i2], caption: 'Test caption'))

        allow(client).to receive(:container_status).with('carousel').and_return(status('FINISHED'))
        attempt

        expect(client).to have_received(:publish_container).once
        expect(entry.reload.instagram_shares_count).to eq(1)
      end

      it 'starts over when Meta fails one of its photos' do
        expect { attempt }.to raise_error(MetaContainerPendingError)
        allow(client).to receive(:container_status).with('i1').and_return(status('ERROR'))
        allow(client).to receive(:container_status).with('i2').and_return(status('FINISHED'))

        expect { attempt }.to raise_error(MetaContainerPendingError)
        expect(client).to have_received(:create_carousel_items).twice
      end
    end
  end

  describe '.retry_delay' do
    it 'checks on a pending container again in a few seconds' do
      expect(described_class.retry_delay(3, MetaContainerPendingError.new)).to eq(MetaShareJob::PENDING_DELAY)
    end

    it 'gives up on what retrying can’t fix' do
      [MetaCaptionTooLongError, MetaAuthError, MetaContainerFailedError].each do |error|
        expect(described_class.retry_delay(1, error.new)).to eq(:discard)
      end
    end

    it 'leaves anything else to the usual backoff' do
      expect(described_class.retry_delay(1, RuntimeError.new)).to be_nil
    end
  end
end
