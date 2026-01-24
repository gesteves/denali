require 'rails_helper'

RSpec.describe MastodonWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
    create_list(:webhook, 2, blog: blog)
  end

  describe '#perform' do
    let(:text) { 'Test caption for Mastodon' }

    context 'in production environment with credentials' do
      let(:mastodon_instance) { instance_double(Mastodon) }

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('MASTODON_BASE_URL').and_return('https://mastodon.social')
        allow(ENV).to receive(:[]).with('MASTODON_ACCESS_TOKEN').and_return('test_token')
        allow(Mastodon).to receive(:new).and_return(mastodon_instance)
        allow(mastodon_instance).to receive(:upload_media).and_return({ 'id' => '12345' })
        allow(mastodon_instance).to receive(:create_status)
      end

      it 'uploads media and creates status' do
        expect(mastodon_instance).to receive(:upload_media).once
        expect(mastodon_instance).to receive(:create_status).with(
          text: text,
          media_ids: ['12345'],
          sensitive: false,
          spoiler_text: nil
        )

        described_class.new.perform(entry.id, text)
      end

      it 'updates entry with share tracking' do
        described_class.new.perform(entry.id, text)
        entry.reload

        expect(entry.last_shared_on_mastodon_at).not_to be_nil
        expect(entry.mastodon_shares_count).to eq(1)
      end

      it 'handles sensitive content' do
        entry.update!(is_sensitive: true, content_warning: 'Sensitive content')

        expect(mastodon_instance).to receive(:create_status).with(
          text: text,
          media_ids: ['12345'],
          sensitive: true,
          spoiler_text: 'Sensitive content'
        )

        described_class.new.perform(entry.id, text)
      end

      it 'raises UnprocessedPhotoError when photos lack dimensions' do
        allow_any_instance_of(Entry).to receive(:photos_have_dimensions?).and_return(false)

        expect {
          described_class.new.perform(entry.id, text)
        }.to raise_error(UnprocessedPhotoError)
      end
    end

    context 'in non-production environment' do
      it 'returns early without calling Mastodon API' do
        expect(Mastodon).not_to receive(:new)
        described_class.new.perform(entry.id, text)
      end
    end

    context 'without credentials' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('MASTODON_BASE_URL').and_return('')
      end

      it 'returns early without calling Mastodon API' do
        expect(Mastodon).not_to receive(:new)
        described_class.new.perform(entry.id, text)
      end
    end

    context 'with text entry (no photos)' do
      let(:text_entry) { create(:entry, :published, blog: blog, user: user, photos_count: 0) }

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('MASTODON_BASE_URL').and_return('https://mastodon.social')
        allow(ENV).to receive(:[]).with('MASTODON_ACCESS_TOKEN').and_return('test_token')
      end

      it 'returns early for non-photo entries' do
        expect(Mastodon).not_to receive(:new)
        described_class.new.perform(text_entry.id, text)
      end
    end
  end

  describe 'Sidekiq configuration' do
    it 'uses the high queue' do
      expect(described_class.sidekiq_options['queue']).to eq('high')
    end
  end
end
