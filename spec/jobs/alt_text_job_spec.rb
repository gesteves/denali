require 'rails_helper'

RSpec.describe AltTextJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, blog: blog, user: user) }
  let(:photo) { create(:photo, entry: entry) }

  before do
    attach_image_to_photo(photo)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('test_key')
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('ANTHROPIC_MODEL', anything).and_return('claude-haiku-4-5')
  end

  describe '#perform' do
    let(:claude_instance) { instance_double(Claude) }
    let(:api_response) do
      {
        'content' => [
          { 'text' => 'A beautiful sunset over mountains with golden light' }
        ]
      }
    end

    before do
      allow(Claude).to receive(:new).and_return(claude_instance)
      allow(claude_instance).to receive(:create_message).and_return(api_response)
    end

    it 'sends image to Claude API for alt text generation' do
      expect(claude_instance).to receive(:create_message) do |body|
        expect(body[:model]).to eq('claude-haiku-4-5')
        expect(body[:messages].first[:content]).to include(
          hash_including(type: 'image')
        )
      end.and_return(api_response)

      described_class.new.perform(photo.id)
    end

    it 'saves auto-generated alt text to photo' do
      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.auto_generated_alt_text).to eq('A beautiful sunset over mountains with golden light')
      expect(photo.alt_text_needs_review).to be true
    end

    it 'raises error when API returns blank alt text' do
      allow(claude_instance).to receive(:create_message).and_return({ 'content' => [{ 'text' => '' }] })

      expect {
        described_class.new.perform(photo.id)
      }.to raise_error(RuntimeError)
    end

    it 'raises UnprocessedPhotoError when photo lacks dimensions' do
      allow_any_instance_of(Photo).to receive(:has_dimensions?).and_return(false)

      expect {
        described_class.new.perform(photo.id)
      }.to raise_error(UnprocessedPhotoError)
    end

    context 'without ANTHROPIC_API_KEY' do
      before do
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('')
      end

      it 'returns early without calling Claude API' do
        expect(Claude).not_to receive(:new)
        described_class.new.perform(photo.id)
      end
    end
  end
end
