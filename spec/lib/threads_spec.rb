require 'rails_helper'

RSpec.describe Threads do
  let(:app_id) { 'test_app_id' }
  let(:app_secret) { 'test_app_secret' }
  let(:threads_user_id) { '987654321' }
  let(:access_token) { 'test_access_token' }
  let(:refreshed_token) { 'refreshed_test_token' }

  # Helper to stub token refresh
  def stub_token_refresh(success: true)
    if success
      stub_request(:get, "#{described_class::THREADS_BASIC_API_BASE}/refresh_access_token")
        .with(query: hash_including(grant_type: 'th_refresh_token'))
        .to_return(
          status: 200,
          body: { access_token: refreshed_token, expires_in: 5184000 }.to_json
        )
    else
      stub_request(:get, "#{described_class::THREADS_BASIC_API_BASE}/refresh_access_token")
        .to_return(status: 400, body: { error: 'invalid_token' }.to_json)
    end
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('THREADS_ACCESS_TOKEN').and_return(access_token)
    allow(Rails.cache).to receive(:read).and_return(nil)
    allow(Rails.cache).to receive(:write)
    allow(Rails.cache).to receive(:delete)
  end

  describe '#initialize' do
    context 'with successful token refresh' do
      before { stub_token_refresh }

      it 'refreshes and caches the token on initialization' do
        expect(Rails.cache).to receive(:write).with(
          "threads:#{threads_user_id}:access_token",
          refreshed_token,
          expires_in: 5184000.seconds
        )

        described_class.new(app_id: app_id, app_secret: app_secret, threads_user_id: threads_user_id)
      end
    end

    context 'when token refresh fails' do
      before do
        stub_request(:get, "#{described_class::THREADS_BASIC_API_BASE}/refresh_access_token")
          .to_return(status: 400, body: { error: 'invalid_token' }.to_json)
      end

      it 'clears cache and raises an error' do
        expect(Rails.cache).to receive(:delete).with("threads:#{threads_user_id}:access_token")

        expect {
          described_class.new(app_id: app_id, app_secret: app_secret, threads_user_id: threads_user_id)
        }.to raise_error(RuntimeError, /Failed to initialize Threads/)
      end
    end

    context 'when no token is available' do
      before do
        allow(ENV).to receive(:[]).with('THREADS_ACCESS_TOKEN').and_return(nil)
      end

      it 'raises an error' do
        expect {
          described_class.new(app_id: app_id, app_secret: app_secret, threads_user_id: threads_user_id)
        }.to raise_error(RuntimeError, /No access token found/)
      end
    end
  end

  describe '#post' do
    let(:photo) { { url: 'https://example.com/photo.jpg', alt_text: 'A test photo' } }
    let(:caption) { 'Test caption' }
    let(:container_id) { 'container_123' }
    let(:threads_endpoint) { "#{described_class::THREADS_API_BASE}/#{threads_user_id}/threads" }
    let(:publish_endpoint) { "#{described_class::THREADS_API_BASE}/#{threads_user_id}/threads_publish" }
    let(:threads) { described_class.new(app_id: app_id, app_secret: app_secret, threads_user_id: threads_user_id) }

    before do
      stub_token_refresh
      allow(Rails.cache).to receive(:read).with("threads:#{threads_user_id}:access_token").and_return(refreshed_token)

      # Stub container creation - match any query params
      stub_request(:post, threads_endpoint)
        .with(query: hash_including(access_token: refreshed_token))
        .to_return(status: 200, body: { id: container_id }.to_json)

      # Stub container status check
      stub_request(:get, "#{described_class::THREADS_API_BASE}/#{container_id}")
        .with(query: hash_including(access_token: refreshed_token))
        .to_return(status: 200, body: { status: 'FINISHED' }.to_json)

      # Stub publish
      stub_request(:post, publish_endpoint)
        .with(query: hash_including(access_token: refreshed_token))
        .to_return(status: 200, body: { id: 'post_123' }.to_json)
    end

    context 'with a single photo' do
      it 'creates a media container and publishes it' do
        response = threads.post(photos: [photo], caption: caption)
        expect(response['id']).to eq('post_123')
      end

      it 'sends access_token as query parameter' do
        threads.post(photos: [photo], caption: caption)
        expect(WebMock).to have_requested(:post, threads_endpoint)
          .with(query: hash_including(access_token: refreshed_token))
      end

      it 'includes text in the request body' do
        threads.post(photos: [photo], caption: caption)
        expect(WebMock).to have_requested(:post, /#{threads_endpoint}/)
          .with { |req| req.body.include?('text=Test') }
      end
    end

    context 'with multiple photos (carousel)' do
      let(:photos) do
        [
          { url: 'https://example.com/photo1.jpg', alt_text: 'Photo 1' },
          { url: 'https://example.com/photo2.jpg', alt_text: 'Photo 2' }
        ]
      end
      let(:container_id_1) { 'container_1' }
      let(:container_id_2) { 'container_2' }
      let(:carousel_container_id) { 'carousel_123' }

      before do
        # Stub individual container creations with multiple responses
        stub_request(:post, threads_endpoint)
          .with(query: hash_including(access_token: refreshed_token))
          .to_return(
            { status: 200, body: { id: container_id_1 }.to_json },
            { status: 200, body: { id: container_id_2 }.to_json },
            { status: 200, body: { id: carousel_container_id }.to_json }
          )

        # Stub status checks for each container
        [container_id_1, container_id_2, carousel_container_id].each do |cid|
          stub_request(:get, "#{described_class::THREADS_API_BASE}/#{cid}")
            .with(query: hash_including(access_token: refreshed_token))
            .to_return(status: 200, body: { status: 'FINISHED' }.to_json)
        end
      end

      it 'creates a carousel container with children' do
        response = threads.post(photos: photos, caption: caption)
        expect(response['id']).to eq('post_123')
      end
    end

    context 'with topic_tag and location_id' do
      it 'includes optional parameters' do
        threads.post(photos: [photo], caption: caption, topic_tag: 'photography', location_id: 'loc_123')
        # Check that topic_tag and location_id are included in the request
        expect(WebMock).to have_requested(:post, /#{threads_endpoint}/)
          .with { |req| req.body.include?('topic_tag=photography') && req.body.include?('location_id=loc_123') }
      end
    end

    context 'with empty photos array' do
      it 'raises ArgumentError' do
        expect {
          threads.post(photos: [], caption: caption)
        }.to raise_error(ArgumentError, /Photos array cannot be empty/)
      end
    end

    context 'with more than 20 photos' do
      let(:photos) { 21.times.map { |i| { url: "https://example.com/photo#{i}.jpg", alt_text: "Photo #{i}" } } }

      it 'raises ArgumentError' do
        expect {
          threads.post(photos: photos, caption: caption)
        }.to raise_error(ArgumentError, /Photos array cannot exceed 20 photos/)
      end
    end
  end

  describe 'container status handling' do
    let(:photo) { { url: 'https://example.com/photo.jpg', alt_text: 'A test photo' } }
    let(:container_id) { 'container_123' }
    let(:threads_endpoint) { "#{described_class::THREADS_API_BASE}/#{threads_user_id}/threads" }
    let(:publish_endpoint) { "#{described_class::THREADS_API_BASE}/#{threads_user_id}/threads_publish" }
    let(:threads) { described_class.new(app_id: app_id, app_secret: app_secret, threads_user_id: threads_user_id) }

    before do
      stub_token_refresh
      allow(Rails.cache).to receive(:read).with("threads:#{threads_user_id}:access_token").and_return(refreshed_token)

      stub_request(:post, threads_endpoint)
        .with(query: hash_including(access_token: refreshed_token))
        .to_return(status: 200, body: { id: container_id }.to_json)

      stub_request(:post, publish_endpoint)
        .with(query: hash_including(access_token: refreshed_token))
        .to_return(status: 200, body: { id: 'post_123' }.to_json)
    end

    context 'when container status is ERROR' do
      before do
        stub_request(:get, "#{described_class::THREADS_API_BASE}/#{container_id}")
          .with(query: hash_including(access_token: refreshed_token))
          .to_return(status: 200, body: { status: 'ERROR' }.to_json)
      end

      it 'raises an error' do
        expect {
          threads.post(photos: [photo], caption: 'Test')
        }.to raise_error(RuntimeError, /failed with ERROR status/)
      end
    end

    context 'when container status is EXPIRED' do
      before do
        stub_request(:get, "#{described_class::THREADS_API_BASE}/#{container_id}")
          .with(query: hash_including(access_token: refreshed_token))
          .to_return(status: 200, body: { status: 'EXPIRED' }.to_json)
      end

      it 'raises an error' do
        expect {
          threads.post(photos: [photo], caption: 'Test')
        }.to raise_error(RuntimeError, /expired before it could be published/)
      end
    end

    context 'when container status is PUBLISHED' do
      before do
        stub_request(:get, "#{described_class::THREADS_API_BASE}/#{container_id}")
          .with(query: hash_including(access_token: refreshed_token))
          .to_return(status: 200, body: { status: 'PUBLISHED' }.to_json)
      end

      it 'returns successfully' do
        response = threads.post(photos: [photo], caption: 'Test')
        expect(response['id']).to eq('post_123')
      end
    end
  end

  describe 'constants' do
    it 'has correct API base URLs' do
      expect(described_class::THREADS_API_BASE).to eq('https://graph.threads.net/v1.0')
      expect(described_class::THREADS_BASIC_API_BASE).to eq('https://graph.threads.net')
    end
  end
end
