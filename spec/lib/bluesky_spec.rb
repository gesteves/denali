require 'rails_helper'

RSpec.describe Bluesky do
  describe '.valid_post_length?' do
    it 'returns true for text under 300 graphemes' do
      expect(described_class.valid_post_length?('Hello, world!')).to be true
    end

    it 'returns true for text exactly 300 graphemes' do
      text = 'a' * 300
      expect(described_class.valid_post_length?(text)).to be true
    end

    it 'returns false for text over 300 graphemes' do
      text = 'a' * 301
      expect(described_class.valid_post_length?(text)).to be false
    end

    it 'returns false for non-string input' do
      expect(described_class.valid_post_length?(nil)).to be false
      expect(described_class.valid_post_length?(123)).to be false
    end

    it 'handles markdown links correctly' do
      # The link text counts, not the URL
      text = '[short link](https://example.com/very/long/url/that/would/exceed/limit)'
      expect(described_class.valid_post_length?(text)).to be true
    end

    it 'handles emoji and unicode correctly' do
      # Each emoji is one grapheme
      text = '🎉' * 300
      expect(described_class.valid_post_length?(text)).to be true

      text = '🎉' * 301
      expect(described_class.valid_post_length?(text)).to be false
    end
  end

  describe '.post_length' do
    it 'returns the correct grapheme count' do
      expect(described_class.post_length('Hello')).to eq(5)
    end

    it 'counts emoji as single graphemes' do
      expect(described_class.post_length('👨‍👩‍👧‍👦')).to eq(1) # Family emoji is one grapheme
    end

    it 'strips markdown from count' do
      text = '[link text](https://example.com)'
      expect(described_class.post_length(text)).to eq(9) # 'link text' is 9 characters
    end
  end

  describe 'instance methods' do
    let(:base_url) { 'https://bsky.social' }
    let(:email) { 'test@example.com' }
    let(:password) { 'password123' }
    let(:bluesky) { described_class.new(base_url: base_url, email: email, password: password) }

    before do
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write)
    end

    describe '#skeet' do
      let(:text) { 'Hello, Bluesky!' }
      let(:session_response) do
        {
          'did' => 'did:plc:abcd1234',
          'accessJwt' => 'test_token'
        }
      end

      before do
        stub_request(:post, "#{base_url}/xrpc/com.atproto.server.createSession")
          .to_return(status: 200, body: session_response.to_json)

        stub_request(:post, "#{base_url}/xrpc/com.atproto.repo.createRecord")
          .to_return(status: 200, body: { uri: 'at://did:plc:abcd1234/app.bsky.feed.post/123' }.to_json)
      end

      it 'creates a skeet successfully' do
        response = bluesky.skeet(text: text)
        expect(response['uri']).to include('app.bsky.feed.post')
      end

      it 'creates session when not cached' do
        bluesky.skeet(text: text)
        expect(WebMock).to have_requested(:post, "#{base_url}/xrpc/com.atproto.server.createSession").at_least_once
      end

      context 'with photos' do
        let(:photos) do
          [
            { url: 'https://example.com/photo.jpg', alt_text: 'A photo', width: 1920, height: 1080 }
          ]
        end

        before do
          stub_request(:get, 'https://example.com/photo.jpg')
            .to_return(status: 200, body: 'fake image data')

          stub_request(:post, "#{base_url}/xrpc/com.atproto.repo.uploadBlob")
            .to_return(status: 200, body: { blob: { ref: 'blob123' } }.to_json)
        end

        it 'uploads photos and includes them in the skeet' do
          bluesky.skeet(text: text, photos: photos)
          expect(WebMock).to have_requested(:post, "#{base_url}/xrpc/com.atproto.repo.uploadBlob")
        end
      end

      context 'with reply' do
        let(:reply_url) { 'https://bsky.app/profile/test.bsky.social/post/abc123' }

        before do
          stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
            .with(query: hash_including('handle' => 'test.bsky.social'))
            .to_return(status: 200, body: { did: 'did:plc:test123' }.to_json)

          stub_request(:get, "#{base_url}/xrpc/app.bsky.feed.getPostThread")
            .with(query: hash_including('uri'))
            .to_return(status: 200, body: {
              thread: {
                post: {
                  uri: 'at://did:plc:test123/app.bsky.feed.post/abc123',
                  cid: 'cid123',
                  record: {}
                }
              }
            }.to_json)
        end

        it 'constructs reply object' do
          bluesky.skeet(text: text, in_reply_to: reply_url)
          expect(WebMock).to have_requested(:post, "#{base_url}/xrpc/com.atproto.repo.createRecord")
        end
      end
    end

    describe '#valid_post_length?' do
      it 'delegates to class method' do
        expect(bluesky.valid_post_length?('test')).to be true
      end
    end

    describe '#post_length' do
      it 'delegates to class method' do
        expect(bluesky.post_length('hello')).to eq(5)
      end
    end
  end
end
