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

    it 'rejects empty strings' do
      expect(described_class.valid_post_length?('')).to be false
    end

    it 'rejects strings with only whitespace' do
      expect(described_class.valid_post_length?('   ')).to be false
    end

    it 'rejects text within the grapheme limit but over the byte limit' do
      # A family emoji is one grapheme and 25 bytes. app.bsky.feed.post#text caps both, and only
      # the byte limit catches this.
      text = "\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466}" * 250

      expect(described_class.post_length(text)).to be <= described_class::MAX_POST_LENGTH
      expect(text.bytesize).to be > described_class::MAX_POST_BYTES
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

      context 'with an image over the blob size limit' do
        let(:photos) do
          [{ url: 'https://example.com/photo.jpg', alt_text: 'A photo', width: 4000, height: 3000 }]
        end

        # A body larger than Bluesky's 2,000,000-byte blob limit.
        let(:oversized_body) { 'x' * (described_class::MAX_BLOB_SIZE + 1) }
        # What recompression produces: comfortably under the limit.
        let(:compressed_blob) { 'y' * 1_000_000 }

        before do
          stub_request(:post, "#{base_url}/xrpc/com.atproto.server.createSession")
            .to_return(status: 200, body: session_response.to_json)

          stub_request(:get, 'https://example.com/photo.jpg')
            .to_return(status: 200, body: oversized_body, headers: { 'Content-Type' => 'image/jpeg' })

          stub_request(:post, "#{base_url}/xrpc/com.atproto.repo.uploadBlob")
            .to_return(status: 200, body: { blob: { ref: 'blob123' } }.to_json)

          stub_request(:post, "#{base_url}/xrpc/com.atproto.repo.createRecord")
            .to_return(status: 200, body: { uri: 'at://did:plc:abcd1234/app.bsky.feed.post/123' }.to_json)

          image = instance_double(MiniMagick::Image)
          allow(MiniMagick::Image).to receive(:read).and_return(image)
          allow(image).to receive(:format)
          allow(image).to receive(:combine_options)
          allow(image).to receive(:to_blob).and_return(compressed_blob)
        end

        it 'recompresses the image before uploading it' do
          bluesky.skeet(text: text, photos: photos)

          expect(MiniMagick::Image).to have_received(:read).with(oversized_body)
          expect(WebMock).to have_requested(:post, "#{base_url}/xrpc/com.atproto.repo.uploadBlob")
            .with(body: compressed_blob, headers: { 'Content-Type' => 'image/jpeg' })
        end

        it 'does not upload the original oversized blob' do
          bluesky.skeet(text: text, photos: photos)

          expect(WebMock).not_to have_requested(:post, "#{base_url}/xrpc/com.atproto.repo.uploadBlob")
            .with(body: oversized_body)
        end
      end

      context 'with an image under the blob size limit' do
        let(:photos) do
          [{ url: 'https://example.com/photo.jpg', alt_text: 'A photo', width: 1920, height: 1080 }]
        end

        before do
          stub_request(:post, "#{base_url}/xrpc/com.atproto.server.createSession")
            .to_return(status: 200, body: session_response.to_json)

          stub_request(:get, 'https://example.com/photo.jpg')
            .to_return(status: 200, body: 'small image data', headers: { 'Content-Type' => 'image/jpeg' })

          stub_request(:post, "#{base_url}/xrpc/com.atproto.repo.uploadBlob")
            .to_return(status: 200, body: { blob: { ref: 'blob123' } }.to_json)

          stub_request(:post, "#{base_url}/xrpc/com.atproto.repo.createRecord")
            .to_return(status: 200, body: { uri: 'at://did:plc:abcd1234/app.bsky.feed.post/123' }.to_json)

          allow(MiniMagick::Image).to receive(:read)
        end

        it 'uploads the image as-is without recompressing it' do
          bluesky.skeet(text: text, photos: photos)

          expect(MiniMagick::Image).not_to have_received(:read)
          expect(WebMock).to have_requested(:post, "#{base_url}/xrpc/com.atproto.repo.uploadBlob")
            .with(body: 'small image data')
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

    describe '.render' do
      it 'reduces a markdown link to its words' do
        post = described_class.render('Check out [my website](https://example.com)!')

        expect(post.text).to eq('Check out my website!')
        expect(post.links.map(&:url)).to eq(['https://example.com'])
      end

      it 'leaves a span that is not a link exactly as written' do
        expect(described_class.render('I ate [a lot](really)').text).to eq('I ate [a lot](really)')
      end

      it 'resolves a reference link and removes its definition line' do
        post = described_class.render("Read [my post][ref]\n\n[ref]: https://example.com")

        expect(post.text).to eq('Read my post')
        expect(post.links.map(&:url)).to eq(['https://example.com'])
      end

      it 'resolves a collapsed reference link' do
        post = described_class.render("Read [ref]\n\n[ref]: https://example.com")

        expect(post.text).to eq('Read ref')
        expect(post.links.map(&:url)).to eq(['https://example.com'])
      end

      it 'keeps characters that a markdown renderer would have eaten' do
        # Redcarpet would read the leading "#" as a heading and drop it, and would eat the
        # asterisks, underscores and backticks as emphasis and code.
        text = "#hashtag at the start\n\n*not emphasis* and _not either_ and `code`"

        expect(described_class.render(text).text).to eq(text)
      end

      it 'applies the site typography' do
        expect(described_class.render(%q{It's a "big" day...}).text).to eq('It’s a “big” day…')
      end

      it 'leaves the characters of a URL alone' do
        # SmartyPants reads "--", "..." and quotes in an address as punctuation, and every one of
        # those makes a dead link.
        text = 'See https://example.com/a--b...c?q="d" now'

        expect(described_class.render(text).text).to eq(text)
      end

      it 'preserves line breaks' do
        expect(described_class.render("Line 1\n\nLine 2").text).to eq("Line 1\n\nLine 2")
      end

      it 'decodes HTML entities' do
        expect(described_class.render('Tom &amp; Jerry').text).to eq('Tom & Jerry')
      end
    end

    describe '.link_ranges' do
      it 'returns a markdown link and a bare URL, in order' do
        post = described_class.render('Visit https://a.example or [b](https://b.example)')
        links = described_class.link_ranges(post.text, post.links)

        expect(links.map(&:url)).to eq(['https://a.example', 'https://b.example'])
        expect(links.map(&:start)).to eq(links.map(&:start).sort)
      end

      it 'does not treat a bare URL inside a link label as a second link' do
        post = described_class.render('[https://a.example](https://b.example)')
        links = described_class.link_ranges(post.text, post.links)

        expect(links.map(&:url)).to eq(['https://b.example'])
      end
    end

    describe '#mention_facets' do
      before do
        stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
          .with(query: { 'handle' => 'alice.bsky.social' })
          .to_return(status: 200, body: { did: 'did:plc:alice123' }.to_json)

        stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
          .with(query: { 'handle' => 'bob.bsky.social' })
          .to_return(status: 200, body: { did: 'did:plc:bob456' }.to_json)
      end

      it 'parses a single mention' do
        facets = bluesky.send(:mention_facets, 'Hello @alice.bsky.social!')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#mention')
        expect(facets[0]['features'][0]['did']).to eq('did:plc:alice123')
      end

      it 'parses multiple mentions' do
        facets = bluesky.send(:mention_facets, 'Hello @alice.bsky.social and @bob.bsky.social!')

        expect(facets.size).to eq(2)
        expect(facets[0]['features'][0]['did']).to eq('did:plc:alice123')
        expect(facets[1]['features'][0]['did']).to eq('did:plc:bob456')
      end

      it 'parses mention at the start of text' do
        facets = bluesky.send(:mention_facets, '@alice.bsky.social is great')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['did']).to eq('did:plc:alice123')
      end

      it 'skips mentions that cannot be resolved' do
        stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
          .with(query: { 'handle' => 'nonexistent.bsky.social' })
          .to_return(status: 400, body: { error: 'InvalidHandle' }.to_json)

        expect(bluesky.send(:mention_facets, 'Hello @nonexistent.bsky.social!')).to be_empty
      end

      it 'returns empty array for text without mentions' do
        expect(bluesky.send(:mention_facets, 'Hello world!')).to be_empty
      end

      it 'calculates correct byte offsets' do
        text = 'Hi @alice.bsky.social!'
        facets = bluesky.send(:mention_facets, text)

        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']

        expect(text.byteslice(byte_start, byte_end - byte_start)).to eq('@alice.bsky.social')
      end

      it 'handles mentions with unicode characters before them' do
        text = '🎉 @alice.bsky.social!'
        facets = bluesky.send(:mention_facets, text)

        expect(facets.size).to eq(1)
        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']
        expect(text.byteslice(byte_start, byte_end - byte_start)).to eq('@alice.bsky.social')
      end

      it 'skips a mention that falls inside a link' do
        text = 'https://bsky.app/profile/@me.bsky.social'
        skip_ranges = [0...text.bytesize]

        expect(bluesky.send(:mention_facets, text, skip: skip_ranges)).to be_empty
        expect(a_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")).not_to have_been_made
      end
    end

    describe '#tag_facets' do
      it 'parses a single hashtag' do
        facets = bluesky.send(:tag_facets, 'Hello #world!')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#tag')
        expect(facets[0]['features'][0]['tag']).to eq('world')
      end

      it 'parses multiple hashtags' do
        facets = bluesky.send(:tag_facets, '#hello #world #test')

        expect(facets.size).to eq(3)
        expect(facets.map { |f| f['features'][0]['tag'] }).to eq(%w[hello world test])
      end

      it 'parses hashtag at start of text' do
        facets = bluesky.send(:tag_facets, '#photography is fun')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['tag']).to eq('photography')
      end

      it 'parses hashtags with numbers' do
        facets = bluesky.send(:tag_facets, 'Check out #photo123')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['tag']).to eq('photo123')
      end

      it 'parses hashtags with underscores' do
        facets = bluesky.send(:tag_facets, 'Love #street_photography')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['tag']).to eq('street_photography')
      end

      it 'parses a hashtag with non-ASCII letters in full' do
        # Ruby's \w is ASCII-only, which used to tag this "caf".
        facets = bluesky.send(:tag_facets, 'Morning #café run')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['tag']).to eq('café')
      end

      it 'keeps a hyphen inside a hashtag' do
        facets = bluesky.send(:tag_facets, 'A #trail-run today')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['tag']).to eq('trail-run')
      end

      it 'does not tag a number' do
        expect(bluesky.send(:tag_facets, 'Ranked #1 today')).to be_empty
      end

      it 'drops a hashtag longer than the tag limit' do
        long = 'a' * (described_class::MAX_TAG_GRAPHEMES + 1)

        expect(bluesky.send(:tag_facets, "Hello ##{long}")).to be_empty
      end

      it 'returns empty array for text without hashtags' do
        expect(bluesky.send(:tag_facets, 'Hello world!')).to be_empty
      end

      it 'calculates correct byte offsets' do
        text = 'Hello #world!'
        facets = bluesky.send(:tag_facets, text)

        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']
        expect(text.byteslice(byte_start, byte_end - byte_start)).to eq('#world')
      end

      it 'handles hashtags with unicode before them' do
        text = '🎉 #celebration'
        facets = bluesky.send(:tag_facets, text)

        expect(facets.size).to eq(1)
        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']
        expect(text.byteslice(byte_start, byte_end - byte_start)).to eq('#celebration')
      end

      it 'skips a hashtag that falls inside a link' do
        text = 'https://example.com/#section'
        skip_ranges = [0...text.bytesize]

        expect(bluesky.send(:tag_facets, text, skip: skip_ranges)).to be_empty
      end
    end

    describe '#build_facets' do
      before do
        stub_request(:get, "#{base_url}/xrpc/com.atproto.identity.resolveHandle")
          .with(query: { 'handle' => 'alice.bsky.social' })
          .to_return(status: 200, body: { did: 'did:plc:alice123' }.to_json)
      end

      # Renders the raw text the way #skeet does, then builds its facets from that same parse.
      def facets_for(text)
        post = described_class.render(text)
        [bluesky.send(:build_facets, post.text, links: post.links), post.text]
      end

      it 'combines mentions, URLs, and tags' do
        facets, plain_text = facets_for('Hey @alice.bsky.social, check [this](https://example.com) #cool')

        expect(plain_text).to eq('Hey @alice.bsky.social, check this #cool')

        types = facets.map { |f| f['features'][0]['$type'] }
        expect(types).to include('app.bsky.richtext.facet#link')
        expect(types).to include('app.bsky.richtext.facet#mention')
        expect(types).to include('app.bsky.richtext.facet#tag')
      end

      it 'returns the facets sorted by where they start' do
        facets, = facets_for('#early then [a link](https://example.com) and @alice.bsky.social')

        starts = facets.map { |f| f['index']['byteStart'] }
        expect(starts).to eq(starts.sort)
      end

      it 'handles text with only mentions' do
        facets, = facets_for('Hello @alice.bsky.social!')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#mention')
      end

      it 'handles text with only URLs' do
        facets, = facets_for('Visit https://example.com')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#link')
      end

      it 'handles text with only tags' do
        facets, = facets_for('Loving #photography')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#tag')
      end

      it 'handles empty text' do
        facets, plain_text = facets_for('')

        expect(facets).to be_empty
        expect(plain_text).to eq('')
      end

      it 'handles text with no facets' do
        facets, plain_text = facets_for('Just plain text')

        expect(facets).to be_empty
        expect(plain_text).to eq('Just plain text')
      end

      it 'calculates correct byte offsets after markdown is resolved' do
        facets, plain_text = facets_for('Check [this link](https://example.com) out!')

        expect(plain_text).to eq('Check this link out!')

        url_facet = facets.find { |f| f['features'][0]['$type'] == 'app.bsky.richtext.facet#link' }
        byte_start = url_facet['index']['byteStart']
        byte_end = url_facet['index']['byteEnd']
        expect(plain_text.byteslice(byte_start, byte_end - byte_start)).to eq('this link')
      end

      it 'calculates correct byte offsets when multi-byte characters precede a link' do
        facets, plain_text = facets_for('café [x](https://example.com)')

        byte_start = facets[0]['index']['byteStart']
        byte_end = facets[0]['index']['byteEnd']
        expect(plain_text.byteslice(byte_start, byte_end - byte_start)).to eq('x')
      end

      it 'only links the words of the link, not an earlier copy of them' do
        facets, plain_text = facets_for('Ada said hello. Read [hello](https://example.com).')

        expect(facets.size).to eq(1)
        byte_start = facets[0]['index']['byteStart']
        expect(plain_text.byteslice(0, byte_start)).to eq('Ada said hello. Read ')
      end

      it 'gives two links with the same words their own ranges' do
        facets, = facets_for('[docs](https://a.example) and [docs](https://b.example)')

        expect(facets.size).to eq(2)
        expect(facets.map { |f| f['features'][0]['uri'] }).to eq(['https://a.example', 'https://b.example'])
        expect(facets[0]['index']['byteEnd']).to be <= facets[1]['index']['byteStart']
      end

      it 'leaves a link with no words alone and never emits an empty facet' do
        facets, plain_text = facets_for('[](https://example.com) hi')

        # The span has no words to tap, so it stays verbatim; the address is then a bare URL and
        # gets one facet over the text a reader can actually see.
        expect(plain_text).to eq('[](https://example.com) hi')
        expect(facets.size).to eq(1)
        expect(plain_text.byteslice(facets[0]['index']['byteStart'],
                                    facets[0]['index']['byteEnd'] - facets[0]['index']['byteStart']))
          .to eq('https://example.com')
        expect(facets).to all(satisfy { |f| f['index']['byteEnd'] > f['index']['byteStart'] })
      end

      it 'does not tag the fragment of a URL' do
        facets, = facets_for('Read https://example.com/#section')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#link')
      end

      it 'does not mention a handle inside a URL' do
        facets, = facets_for('See https://bsky.app/profile/@me.bsky.social')

        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['$type']).to eq('app.bsky.richtext.facet#link')
      end

      it 'tags a hashtag at the start of a line' do
        facets, plain_text = facets_for('#hashtag at the start')

        expect(plain_text).to eq('#hashtag at the start')
        expect(facets.size).to eq(1)
        expect(facets[0]['features'][0]['tag']).to eq('hashtag')
      end
    end
  end
end
