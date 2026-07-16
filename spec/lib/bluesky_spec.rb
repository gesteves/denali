require 'rails_helper'

RSpec.describe Bluesky do
  describe 'constants' do
    it 'defines MAX_POST_LENGTH' do
      expect(described_class::MAX_POST_LENGTH).to eq(300)
    end

    it 'defines MAX_PHOTOS' do
      expect(described_class::MAX_PHOTOS).to eq(4)
    end
  end

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

    it 'handles empty strings' do
      expect(described_class.valid_post_length?('')).to be true
    end

    it 'handles strings with only whitespace' do
      expect(described_class.valid_post_length?('   ')).to be true
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

    describe '#create_threadgate' do
      let(:post_uri) { 'at://did:plc:abcd1234/app.bsky.feed.post/123' }
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
          .to_return(status: 200, body: { uri: 'at://did:plc:abcd1234/app.bsky.feed.threadgate/123' }.to_json)
      end

      it 'allows replies only from followers and people the account follows' do
        bluesky.create_threadgate(post_uri)

        expect(WebMock).to have_requested(:post, "#{base_url}/xrpc/com.atproto.repo.createRecord")
          .with { |req|
            body = JSON.parse(req.body)
            body['collection'] == 'app.bsky.feed.threadgate' &&
              body['record']['post'] == post_uri &&
              body['record']['allow'] == [
                { '$type' => 'app.bsky.feed.threadgate#followerRule' },
                { '$type' => 'app.bsky.feed.threadgate#followingRule' }
              ]
          }
      end

      it 'reuses the post rkey so the gate attaches to the post' do
        bluesky.create_threadgate(post_uri)

        expect(WebMock).to have_requested(:post, "#{base_url}/xrpc/com.atproto.repo.createRecord")
          .with { |req| JSON.parse(req.body)['rkey'] == '123' }
      end

      it 'raises an ArgumentError for a blank at-uri' do
        expect { bluesky.create_threadgate(nil) }.to raise_error(ArgumentError)
      end

      it 'raises an ArgumentError for a malformed at-uri' do
        expect { bluesky.create_threadgate('https://bsky.app/profile/test/post/123') }.to raise_error(ArgumentError)
      end

      it 'raises when the API request fails, so the job can retry' do
        stub_request(:post, "#{base_url}/xrpc/com.atproto.repo.createRecord")
          .to_return(status: 500, body: { error: 'InternalServerError' }.to_json)

        expect { bluesky.create_threadgate(post_uri) }.to raise_error(/Failed to create/)
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

    describe '#skeet' do
      let(:text) { 'Hello, Bluesky!' }
      let(:session_response) do
        {
          'did' => 'did:plc:abcd1234',
          'accessJwt' => 'test_token'
        }
      end

      context 'when API returns an error' do
        before do
          stub_request(:post, "#{base_url}/xrpc/com.atproto.server.createSession")
            .to_return(status: 200, body: session_response.to_json)

          stub_request(:post, "#{base_url}/xrpc/com.atproto.repo.createRecord")
            .to_return(status: 500, body: { error: 'InternalServerError' }.to_json)
        end

        it 'raises an error with the response body' do
          expect { bluesky.skeet(text: text) }.to raise_error(/Failed to create/)
        end
      end

      context 'with photo upload failure' do
        let(:photos) do
          [{ url: 'https://example.com/photo.jpg', alt_text: 'A photo', width: 1920, height: 1080 }]
        end

        before do
          stub_request(:post, "#{base_url}/xrpc/com.atproto.server.createSession")
            .to_return(status: 200, body: session_response.to_json)

          stub_request(:get, 'https://example.com/photo.jpg')
            .to_return(status: 404, body: 'Not Found')
        end

        it 'raises an error when image fetch fails' do
          expect { bluesky.skeet(text: text, photos: photos) }.to raise_error(/Failed to fetch image/)
        end
      end

      context 'with different image content types' do
        let(:photos) do
          [{ url: 'https://example.com/photo.png', alt_text: 'A PNG', width: 1920, height: 1080 }]
        end

        before do
          stub_request(:post, "#{base_url}/xrpc/com.atproto.server.createSession")
            .to_return(status: 200, body: session_response.to_json)

          stub_request(:get, 'https://example.com/photo.png')
            .to_return(status: 200, body: 'fake image data', headers: { 'Content-Type' => 'image/png' })

          stub_request(:post, "#{base_url}/xrpc/com.atproto.repo.uploadBlob")
            .with(headers: { 'Content-Type' => 'image/png' })
            .to_return(status: 200, body: { blob: { ref: 'blob123' } }.to_json)

          stub_request(:post, "#{base_url}/xrpc/com.atproto.repo.createRecord")
            .to_return(status: 200, body: { uri: 'at://did:plc:abcd1234/app.bsky.feed.post/123' }.to_json)
        end

        it 'uses the correct content type from the image response' do
          bluesky.skeet(text: text, photos: photos)
          expect(WebMock).to have_requested(:post, "#{base_url}/xrpc/com.atproto.repo.uploadBlob")
            .with(headers: { 'Content-Type' => 'image/png' })
        end
      end
    end

    describe 'resolve_handle error handling' do
      context 'when API returns non-400 error' do
        before do
          stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
            .with(query: { 'handle' => 'invalid.handle' })
            .to_return(status: 500, body: 'Internal Server Error')
        end

        it 'returns nil for server errors' do
          result = bluesky.send(:resolve_handle, 'invalid.handle')
          expect(result).to be_nil
        end
      end

      context 'when API returns invalid JSON' do
        before do
          stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
            .with(query: { 'handle' => 'malformed.handle' })
            .to_return(status: 200, body: 'not valid json')
        end

        it 'returns nil for malformed responses' do
          result = bluesky.send(:resolve_handle, 'malformed.handle')
          expect(result).to be_nil
        end
      end
    end

    describe 'post_url_to_at_uri edge cases' do
      let(:session_response) do
        {
          'did' => 'did:plc:abcd1234',
          'accessJwt' => 'test_token'
        }
      end

      before do
        stub_request(:post, "#{base_url}/xrpc/com.atproto.server.createSession")
          .to_return(status: 200, body: session_response.to_json)
      end

      it 'returns nil for non-bsky.app URLs' do
        result = bluesky.send(:post_url_to_at_uri, 'https://twitter.com/user/status/123')
        expect(result).to be_nil
      end

      it 'returns nil for invalid bsky.app paths' do
        result = bluesky.send(:post_url_to_at_uri, 'https://bsky.app/settings')
        expect(result).to be_nil
      end

      it 'returns nil for URLs with missing post ID' do
        result = bluesky.send(:post_url_to_at_uri, 'https://bsky.app/profile/test.bsky.social/post/')
        expect(result).to be_nil
      end

      it 'handles URLs with DID directly' do
        result = bluesky.send(:post_url_to_at_uri, 'https://bsky.app/profile/did:plc:test123/post/abc123')
        expect(result).to eq('at://did:plc:test123/app.bsky.feed.post/abc123')
      end
    end

    describe '#parse_mentions' do
      before do
        stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
          .with(query: { 'handle' => 'alice.bsky.social' })
          .to_return(status: 200, body: { did: 'did:plc:alice123' }.to_json)

        stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
          .with(query: { 'handle' => 'bob.bsky.social' })
          .to_return(status: 200, body: { did: 'did:plc:bob456' }.to_json)
      end

      it 'parses a single mention' do
        text = 'Hello @alice.bsky.social!'
        facets = bluesky.send(:parse_mentions, text)

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#mention')
        expect(facets[0]['features'][0]['did']).to eq('did:plc:alice123')
      end

      it 'parses multiple mentions' do
        text = 'Hello @alice.bsky.social and @bob.bsky.social!'
        facets = bluesky.send(:parse_mentions, text)

        expect(facets.size).to eq(2)
        expect(facets[0]['features'][0]['did']).to eq('did:plc:alice123')
        expect(facets[1]['features'][0]['did']).to eq('did:plc:bob456')
      end

      it 'parses mention at the start of text' do
        text = '@alice.bsky.social is great'
        facets = bluesky.send(:parse_mentions, text)

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['did']).to eq('did:plc:alice123')
      end

      it 'skips mentions that cannot be resolved' do
        stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
          .with(query: { 'handle' => 'nonexistent.bsky.social' })
          .to_return(status: 400, body: { error: 'InvalidHandle' }.to_json)

        text = 'Hello @nonexistent.bsky.social!'
        facets = bluesky.send(:parse_mentions, text)

        expect(facets).to be_empty
      end

      it 'returns empty array for text without mentions' do
        facets = bluesky.send(:parse_mentions, 'Hello world!')
        expect(facets).to be_empty
      end

      it 'calculates correct byte offsets' do
        text = 'Hi @alice.bsky.social!'
        facets = bluesky.send(:parse_mentions, text)

        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']

        expect(text.byteslice(byte_start, byte_end - byte_start)).to eq('@alice.bsky.social')
      end

      it 'handles mentions with unicode characters before them' do
        text = '🎉 @alice.bsky.social!'
        facets = bluesky.send(:parse_mentions, text)

        expect(facets.size).to eq(1)
        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']
        expect(text.byteslice(byte_start, byte_end - byte_start)).to eq('@alice.bsky.social')
      end
    end

    describe '#parse_urls' do
      it 'parses markdown links' do
        text = 'Check out [my website](https://example.com)!'
        facets, plain_text = bluesky.send(:parse_urls, text)

        expect(plain_text).to eq('Check out my website!')
        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#link')
        expect(facets[0]['features'][0]['uri']).to eq('https://example.com')
      end

      it 'parses multiple markdown links' do
        text = 'Visit [Google](https://google.com) or [GitHub](https://github.com)'
        facets, plain_text = bluesky.send(:parse_urls, text)

        expect(plain_text).to eq('Visit Google or GitHub')
        expect(facets.size).to eq(2)
        expect(facets[0]['features'][0]['uri']).to eq('https://google.com')
        expect(facets[1]['features'][0]['uri']).to eq('https://github.com')
      end

      it 'parses autolinked URLs' do
        text = 'Check out https://example.com for more info'
        facets, plain_text = bluesky.send(:parse_urls, text)

        expect(plain_text).to eq('Check out https://example.com for more info')
        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['uri']).to eq('https://example.com')
      end

      it 'returns empty facets for text without URLs' do
        text = 'Just some plain text'
        facets, plain_text = bluesky.send(:parse_urls, text)

        expect(plain_text).to eq('Just some plain text')
        expect(facets).to be_empty
      end

      it 'calculates correct byte offsets for link text' do
        text = 'See [docs](https://docs.example.com) here'
        facets, plain_text = bluesky.send(:parse_urls, text)

        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']
        expect(plain_text.byteslice(byte_start, byte_end - byte_start)).to eq('docs')
      end

      it 'handles unicode in link text' do
        text = 'Check [日本語](https://example.jp)!'
        facets, plain_text = bluesky.send(:parse_urls, text)

        expect(plain_text).to eq('Check 日本語!')
        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']
        expect(plain_text.byteslice(byte_start, byte_end - byte_start)).to eq('日本語')
      end

      it 'preserves line breaks' do
        text = "Line 1\n\nLine 2"
        _, plain_text = bluesky.send(:parse_urls, text)

        expect(plain_text).to eq("Line 1\n\nLine 2")
      end

      it 'decodes HTML entities' do
        text = 'Tom & Jerry'
        _, plain_text = bluesky.send(:parse_urls, text)

        expect(plain_text).to eq('Tom & Jerry')
      end

      it 'handles smart quotes from SmartyPants' do
        text = '"Hello" and \'world\''
        _, plain_text = bluesky.send(:parse_urls, text)

        expect(plain_text).to include('Hello')
        expect(plain_text).to include('world')
      end
    end

    describe '#parse_tags' do
      it 'parses a single hashtag' do
        text = 'Hello #world!'
        facets = bluesky.send(:parse_tags, text)

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#tag')
        expect(facets[0]['features'][0]['tag']).to eq('world')
      end

      it 'parses multiple hashtags' do
        text = '#hello #world #test'
        facets = bluesky.send(:parse_tags, text)

        expect(facets.size).to eq(3)
        expect(facets[0]['features'][0]['tag']).to eq('hello')
        expect(facets[1]['features'][0]['tag']).to eq('world')
        expect(facets[2]['features'][0]['tag']).to eq('test')
      end

      it 'parses hashtag at start of text' do
        text = '#photography is fun'
        facets = bluesky.send(:parse_tags, text)

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['tag']).to eq('photography')
      end

      it 'parses hashtags with numbers' do
        text = 'Check out #photo123'
        facets = bluesky.send(:parse_tags, text)

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['tag']).to eq('photo123')
      end

      it 'parses hashtags with underscores' do
        text = 'Love #street_photography'
        facets = bluesky.send(:parse_tags, text)

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['tag']).to eq('street_photography')
      end

      it 'returns empty array for text without hashtags' do
        facets = bluesky.send(:parse_tags, 'Hello world!')
        expect(facets).to be_empty
      end

      it 'calculates correct byte offsets' do
        text = 'Hello #world!'
        facets = bluesky.send(:parse_tags, text)

        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']
        expect(text.byteslice(byte_start, byte_end - byte_start)).to eq('#world')
      end

      it 'handles hashtags with unicode before them' do
        text = '🎉 #celebration'
        facets = bluesky.send(:parse_tags, text)

        expect(facets.size).to eq(1)
        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']
        expect(text.byteslice(byte_start, byte_end - byte_start)).to eq('#celebration')
      end
    end

    describe '#parse_facets' do
      before do
        stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
          .with(query: { 'handle' => 'alice.bsky.social' })
          .to_return(status: 200, body: { did: 'did:plc:alice123' }.to_json)
      end

      it 'combines mentions, URLs, and tags' do
        text = 'Hey @alice.bsky.social, check [this](https://example.com) #cool'
        facets, plain_text = bluesky.send(:parse_facets, text)

        expect(plain_text).to eq('Hey @alice.bsky.social, check this #cool')

        types = facets.map { |f| f['features'][0]['$type'] }
        expect(types).to include('app.bsky.richtext.facet#link')
        expect(types).to include('app.bsky.richtext.facet#mention')
        expect(types).to include('app.bsky.richtext.facet#tag')
      end

      it 'returns plain text with markdown stripped' do
        text = '**Bold** and [link](https://example.com)'
        _, plain_text = bluesky.send(:parse_facets, text)

        expect(plain_text).to eq('Bold and link')
      end

      it 'handles text with only mentions' do
        text = 'Hello @alice.bsky.social!'
        facets, _ = bluesky.send(:parse_facets, text)

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#mention')
      end

      it 'handles text with only URLs' do
        text = 'Visit https://example.com'
        facets, _ = bluesky.send(:parse_facets, text)

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#link')
      end

      it 'handles text with only tags' do
        text = 'Loving #photography'
        facets, _ = bluesky.send(:parse_facets, text)

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#tag')
      end

      it 'handles empty text' do
        text = ''
        facets, plain_text = bluesky.send(:parse_facets, text)

        expect(facets).to be_empty
        expect(plain_text).to eq('')
      end

      it 'handles text with no facets' do
        text = 'Just plain text'
        facets, plain_text = bluesky.send(:parse_facets, text)

        expect(facets).to be_empty
        expect(plain_text).to eq('Just plain text')
      end

      it 'calculates correct byte offsets after markdown is stripped' do
        text = 'Check [this link](https://example.com) out!'
        facets, plain_text = bluesky.send(:parse_facets, text)

        expect(plain_text).to eq('Check this link out!')

        url_facet = facets.find { |f| f['features'][0]['$type'] == 'app.bsky.richtext.facet#link' }
        byte_start = url_facet['index']['byteStart']
        byte_end = url_facet['index']['byteEnd']
        expect(plain_text.byteslice(byte_start, byte_end - byte_start)).to eq('this link')
      end
    end
  end
end
