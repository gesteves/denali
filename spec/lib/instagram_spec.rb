require 'rails_helper'

RSpec.describe Instagram do
  let(:app_id) { 'test_app_id' }
  let(:app_secret) { 'test_app_secret' }
  let(:access_token) { 'test_access_token' }
  let(:refreshed_token) { 'refreshed_test_token' }
  let(:user) { create(:user) }
  let(:social_account) { create(:social_account, :instagram, user: user, access_token: access_token, connected_at: Time.current) }

  # Helper to stub token refresh
  def stub_token_refresh(from_token: access_token, to_token: refreshed_token, success: true)
    if success
      stub_request(:get, "#{described_class::INSTAGRAM_BASIC_API_BASE}/refresh_access_token")
        .with(query: hash_including(grant_type: 'ig_refresh_token'))
        .to_return(
          status: 200,
          body: { access_token: to_token, expires_in: 5184000 }.to_json
        )
    else
      stub_request(:get, "#{described_class::INSTAGRAM_BASIC_API_BASE}/refresh_access_token")
        .to_return(status: 400, body: { error: 'invalid_token' }.to_json)
    end
  end

  describe '#initialize' do
    context 'with fresh token (connected recently)' do
      it 'does not refresh the token' do
        expect(HTTParty).not_to receive(:get).with(/refresh_access_token/, anything)

        described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account)
      end
    end

    context 'with expiring token (connected more than 30 days ago)' do
      let(:social_account) { create(:social_account, :instagram, user: user, access_token: access_token, connected_at: 31.days.ago) }

      before { stub_token_refresh }

      it 'refreshes and persists the token' do
        described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account)

        social_account.reload
        expect(social_account.access_token).to eq(refreshed_token)
        expect(social_account.connected_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'when token refresh fails' do
      let(:social_account) { create(:social_account, :instagram, user: user, access_token: access_token, connected_at: 31.days.ago) }

      before do
        stub_request(:get, "#{described_class::INSTAGRAM_BASIC_API_BASE}/refresh_access_token")
          .to_return(status: 400, body: { error: 'invalid_token' }.to_json)
      end

      it 'raises an error' do
        expect {
          described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account)
        }.to raise_error(RuntimeError, /Failed to refresh Instagram token/)
      end
    end
  end

  describe '#post' do
    let(:photo) { { url: 'https://example.com/photo.jpg', alt_text: 'A test photo' } }
    let(:caption) { 'Test caption' }
    let(:container_id) { 'container_123' }
    let(:ig_account_id) { social_account.uid }
    let(:media_endpoint) { "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{ig_account_id}/media" }
    let(:publish_endpoint) { "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{ig_account_id}/media_publish" }
    let(:instagram) { described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account) }

    before do
      # Stub container creation
      stub_request(:post, media_endpoint)
        .to_return(status: 200, body: { id: container_id }.to_json)

      # Stub container status check
      stub_request(:get, "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{container_id}")
        .with(query: { fields: 'status_code' })
        .to_return(status: 200, body: { status_code: 'FINISHED' }.to_json)

      # Stub publish
      stub_request(:post, publish_endpoint)
        .to_return(status: 200, body: { id: 'media_123' }.to_json)
    end

    context 'with a single photo' do
      it 'creates a media container and publishes it' do
        response = instagram.post(photos: [photo], caption: caption)
        expect(response['id']).to eq('media_123')
      end

      it 'sends correct authorization header' do
        instagram.post(photos: [photo], caption: caption)
        expect(WebMock).to have_requested(:post, media_endpoint)
          .with(headers: { 'Authorization' => "Bearer #{access_token}" })
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
        # Stub individual container creations
        stub_request(:post, media_endpoint)
          .to_return(
            { status: 200, body: { id: container_id_1 }.to_json },
            { status: 200, body: { id: container_id_2 }.to_json },
            { status: 200, body: { id: carousel_container_id }.to_json }
          )

        # Stub status checks
        stub_request(:get, "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{container_id_1}")
          .with(query: { fields: 'status_code' })
          .to_return(status: 200, body: { status_code: 'FINISHED' }.to_json)

        stub_request(:get, "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{container_id_2}")
          .with(query: { fields: 'status_code' })
          .to_return(status: 200, body: { status_code: 'FINISHED' }.to_json)

        stub_request(:get, "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{carousel_container_id}")
          .with(query: { fields: 'status_code' })
          .to_return(status: 200, body: { status_code: 'FINISHED' }.to_json)
      end

      it 'creates a carousel container with children' do
        response = instagram.post(photos: photos, caption: caption)
        expect(response['id']).to eq('media_123')
      end
    end

    context 'with empty photos array' do
      it 'raises ArgumentError' do
        expect {
          instagram.post(photos: [], caption: caption)
        }.to raise_error(ArgumentError, /Photos array cannot be empty/)
      end
    end

    context 'with more than 10 photos' do
      let(:photos) { 11.times.map { |i| { url: "https://example.com/photo#{i}.jpg", alt_text: "Photo #{i}" } } }

      it 'raises ArgumentError' do
        expect {
          instagram.post(photos: photos, caption: caption)
        }.to raise_error(ArgumentError, /Photos array cannot exceed 10 photos/)
      end
    end
  end

  describe '#post_story' do
    let(:photo_url) { 'https://example.com/story.jpg' }
    let(:story_container_id) { 'story_123' }
    let(:ig_account_id) { social_account.uid }
    let(:media_endpoint) { "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{ig_account_id}/media" }
    let(:publish_endpoint) { "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{ig_account_id}/media_publish" }
    let(:instagram) { described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account) }

    before do
      stub_request(:post, media_endpoint)
        .to_return(status: 200, body: { id: story_container_id }.to_json)

      stub_request(:get, "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{story_container_id}")
        .with(query: { fields: 'status_code' })
        .to_return(status: 200, body: { status_code: 'FINISHED' }.to_json)

      stub_request(:post, publish_endpoint)
        .to_return(status: 200, body: { id: 'published_story_123' }.to_json)
    end

    it 'creates and publishes a story' do
      response = instagram.post_story(photo_url: photo_url)
      expect(response['id']).to eq('published_story_123')
    end

    it 'sends STORIES media type' do
      instagram.post_story(photo_url: photo_url)
      expect(WebMock).to have_requested(:post, media_endpoint)
        .with(body: hash_including('media_type' => 'STORIES'))
    end
  end

  describe '#post_comment' do
    let(:media_id) { 'media_456' }
    let(:message) { 'Great photo!' }
    let(:comments_endpoint) { "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{media_id}/comments" }
    let(:instagram) { described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account) }

    context 'with successful response' do
      before do
        stub_request(:post, comments_endpoint)
          .with(query: { message: message })
          .to_return(status: 200, body: { id: 'comment_123' }.to_json)
      end

      it 'posts a comment and returns the response' do
        response = instagram.post_comment(media_id: media_id, message: message)
        expect(response['id']).to eq('comment_123')
      end
    end

    context 'with blank message' do
      it 'raises ArgumentError' do
        expect {
          instagram.post_comment(media_id: media_id, message: '')
        }.to raise_error(ArgumentError, /Message cannot be blank/)
      end
    end

    context 'with failed response' do
      before do
        stub_request(:post, comments_endpoint)
          .to_return(status: 400, body: { error: 'Invalid request' }.to_json)
      end

      it 'raises an error' do
        expect {
          instagram.post_comment(media_id: media_id, message: message)
        }.to raise_error(RuntimeError, /Failed to post comment/)
      end
    end

    context 'with a transient error response' do
      before do
        stub_request(:post, comments_endpoint)
          .with(query: { message: message })
          .to_return(
            status: 400,
            body: { error: { message: 'An unexpected error has occurred.', type: 'OAuthException', is_transient: true, code: 2 } }.to_json
          )
      end

      it 'raises MetaTransientError' do
        expect {
          instagram.post_comment(media_id: media_id, message: message)
        }.to raise_error(MetaTransientError, /Failed to post comment/)
      end
    end
  end

  describe 'container status handling' do
    let(:photo) { { url: 'https://example.com/photo.jpg', alt_text: 'A test photo' } }
    let(:container_id) { 'container_123' }
    let(:ig_account_id) { social_account.uid }
    let(:media_endpoint) { "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{ig_account_id}/media" }
    let(:publish_endpoint) { "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{ig_account_id}/media_publish" }
    let(:instagram) { described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account) }

    before do
      stub_request(:post, media_endpoint)
        .to_return(status: 200, body: { id: container_id }.to_json)

      stub_request(:post, publish_endpoint)
        .to_return(status: 200, body: { id: 'media_123' }.to_json)
    end

    context 'when container status is ERROR' do
      before do
        stub_request(:get, "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{container_id}")
          .with(query: { fields: 'status_code' })
          .to_return(status: 200, body: { status_code: 'ERROR' }.to_json)
      end

      it 'raises an error' do
        expect {
          instagram.post(photos: [photo], caption: 'Test')
        }.to raise_error(RuntimeError, /failed with ERROR status/)
      end
    end

    context 'when container status is EXPIRED' do
      before do
        stub_request(:get, "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{container_id}")
          .with(query: { fields: 'status_code' })
          .to_return(status: 200, body: { status_code: 'EXPIRED' }.to_json)
      end

      it 'raises an error' do
        expect {
          instagram.post(photos: [photo], caption: 'Test')
        }.to raise_error(RuntimeError, /expired before it could be published/)
      end
    end

    context 'when container status is PUBLISHED' do
      before do
        stub_request(:get, "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{container_id}")
          .with(query: { fields: 'status_code' })
          .to_return(status: 200, body: { status_code: 'PUBLISHED' }.to_json)
      end

      it 'returns successfully' do
        response = instagram.post(photos: [photo], caption: 'Test')
        expect(response['id']).to eq('media_123')
      end
    end
  end

  describe 'transient error handling' do
    let(:ig_account_id) { social_account.uid }
    let(:media_endpoint) { "#{described_class::INSTAGRAM_GRAPH_API_BASE}/#{ig_account_id}/media" }
    let(:instagram) { described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account) }

    context 'when create_media_container returns a transient error' do
      before do
        stub_request(:post, media_endpoint)
          .to_return(
            status: 400,
            body: { error: { message: 'An unexpected error has occurred.', type: 'OAuthException', is_transient: true, code: 2 } }.to_json
          )
      end

      it 'raises MetaTransientError' do
        expect {
          instagram.post(photos: [{ url: 'https://example.com/photo.jpg', alt_text: 'Test' }], caption: 'Test')
        }.to raise_error(MetaTransientError, /Failed to create media container/)
      end
    end

    context 'when create_media_container returns a non-transient error' do
      before do
        stub_request(:post, media_endpoint)
          .to_return(
            status: 400,
            body: { error: { message: 'Invalid token', type: 'OAuthException', is_transient: false, code: 190 } }.to_json
          )
      end

      it 'raises RuntimeError' do
        expect {
          instagram.post(photos: [{ url: 'https://example.com/photo.jpg', alt_text: 'Test' }], caption: 'Test')
        }.to raise_error(RuntimeError, /Failed to create media container/)
      end
    end
  end

  describe 'constants' do
    it 'has correct API base URLs' do
      expect(described_class::INSTAGRAM_GRAPH_API_BASE).to eq('https://graph.instagram.com/v24.0')
      expect(described_class::INSTAGRAM_BASIC_API_BASE).to eq('https://graph.instagram.com')
    end

    it 'has token refresh threshold' do
      expect(described_class::TOKEN_REFRESH_THRESHOLD_DAYS).to eq(30)
    end
  end
end
