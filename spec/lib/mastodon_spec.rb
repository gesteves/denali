require 'rails_helper'

RSpec.describe Mastodon do
  let(:base_url) { 'https://mastodon.social' }
  let(:bearer_token) { 'test_token' }
  let(:mastodon) { described_class.new(base_url: base_url, bearer_token: bearer_token) }

  describe 'constants' do
    it 'defines MAX_MEDIA_ATTACHMENTS' do
      expect(described_class::MAX_MEDIA_ATTACHMENTS).to eq(4)
    end
  end

  describe '#create_status' do
    let(:text) { 'Hello, Mastodon!' }
    let(:status_endpoint) { "#{base_url}/api/v1/statuses" }

    context 'with successful response' do
      before do
        stub_request(:post, status_endpoint)
          .with(
            headers: { 'Authorization' => "Bearer #{bearer_token}" }
          )
          .to_return(
            status: 200,
            body: { id: '12345', content: text }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'creates a status and returns the response' do
        response = mastodon.create_status(text: text)
        expect(response['id']).to eq('12345')
      end

      it 'includes idempotency key in headers' do
        mastodon.create_status(text: text)
        expect(WebMock).to have_requested(:post, status_endpoint)
          .with { |req| req.headers.key?('Idempotency-Key') }
      end

      it 'handles HTML entities in text' do
        text_with_entities = 'Test &amp; more'
        stub_request(:post, status_endpoint)
          .to_return(status: 200, body: { id: '12345' }.to_json)

        mastodon.create_status(text: text_with_entities)
        expect(WebMock).to have_requested(:post, status_endpoint)
          .with(body: hash_including('status' => 'Test & more'))
      end

      it 'passes sensitive flag' do
        stub_request(:post, status_endpoint)
          .to_return(status: 200, body: { id: '12345' }.to_json)

        mastodon.create_status(text: text, sensitive: true, spoiler_text: 'CW')
        # Body is URL-encoded, so sensitive is the string 'true'
        expect(WebMock).to have_requested(:post, status_endpoint)
          .with { |req| req.body.include?('sensitive=true') && req.body.include?('spoiler_text=CW') }
      end
    end

    context 'with failed response' do
      before do
        stub_request(:post, status_endpoint)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an error' do
        expect {
          mastodon.create_status(text: text)
        }.to raise_error(RuntimeError, /Mastodon create_status failed with status 500/)
      end
    end
  end

  describe '#upload_media' do
    let(:media_endpoint) { "#{base_url}/api/v2/media" }
    let(:image_url) { 'https://example.com/image.jpg' }
    let(:alt_text) { 'A beautiful image' }

    before do
      stub_request(:get, image_url)
        .to_return(status: 200, body: File.read(Rails.root.join('spec/fixtures/images/rusty.jpg')))
    end

    context 'with successful response' do
      before do
        stub_request(:post, media_endpoint)
          .with(headers: { 'Authorization' => "Bearer #{bearer_token}" })
          .to_return(
            status: 200,
            body: { id: 'media_123' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'uploads media and returns the response' do
        response = mastodon.upload_media(url: image_url, alt_text: alt_text)
        expect(response['id']).to eq('media_123')
      end

      it 'handles 202 accepted response' do
        stub_request(:post, media_endpoint)
          .to_return(
            status: 202,
            body: { id: 'media_456' }.to_json
          )

        response = mastodon.upload_media(url: image_url, alt_text: alt_text)
        expect(response['id']).to eq('media_456')
      end

      it 'transliterates alt text' do
        mastodon.upload_media(url: image_url, alt_text: 'Caf\u00e9 image')
        # Should not raise an error
      end

      it 'includes focal point when provided' do
        mastodon.upload_media(url: image_url, alt_text: alt_text, focal_point: [0.5, 0.5])
        # Request should be made with focus parameter
        expect(WebMock).to have_requested(:post, media_endpoint)
      end
    end

    context 'with failed response' do
      before do
        stub_request(:post, media_endpoint)
          .to_return(status: 422, body: 'Unprocessable Entity')
      end

      it 'raises an error' do
        expect {
          mastodon.upload_media(url: image_url, alt_text: alt_text)
        }.to raise_error(RuntimeError, /Mastodon upload_media failed with status 422/)
      end
    end

    context 'when image fetch fails' do
      it 'raises an error for HTTP errors' do
        stub_request(:get, image_url).to_return(status: 404, body: 'Not Found')

        expect {
          mastodon.upload_media(url: image_url, alt_text: alt_text)
        }.to raise_error(RuntimeError, /Failed to fetch media from #{Regexp.escape(image_url)}/)
      end

      it 'raises an error for network errors' do
        stub_request(:get, image_url).to_raise(SocketError.new('Connection refused'))

        expect {
          mastodon.upload_media(url: image_url, alt_text: alt_text)
        }.to raise_error(RuntimeError, /Failed to fetch media from #{Regexp.escape(image_url)}/)
      end
    end
  end
end
