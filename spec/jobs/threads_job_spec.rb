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

    it 'posts to Threads and updates entry' do
      threads = instance_double(Threads)
      allow(Threads).to receive(:new).and_return(threads)
      allow(threads).to receive(:post)
      allow_any_instance_of(Entry).to receive(:threads_topic).and_return(nil)
      allow_any_instance_of(Photo).to receive(:threads_location_id).and_return(nil)

      expect(Threads).to receive(:new).with(
        app_id: 'app_id',
        app_secret: 'app_secret',
        social_account: threads_account
      ).and_return(threads)

      expect(threads).to receive(:post).with(
        hash_including(caption: 'Test caption')
      )

      described_class.new.perform(entry.id, 'Test caption')
      entry.reload
      expect(entry.last_shared_on_threads_at).not_to be_nil
      expect(entry.threads_shares_count).to eq(1)
    end
  end
end
