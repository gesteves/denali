require 'rails_helper'

RSpec.describe Threads do
  let(:app_id) { 'test_app_id' }
  let(:app_secret) { 'test_app_secret' }
  let(:threads_user_id) { '987654321' }
  let(:access_token) { 'test_access_token' }
  let(:refreshed_token) { 'refreshed_test_token' }
  let(:user) { create(:user) }
  let(:social_account) { create(:social_account, :threads, user: user, uid: threads_user_id, access_token: access_token, connected_at: Time.current) }

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
        .with(query: hash_including(grant_type: 'th_refresh_token'))
        .to_return(status: 400, body: { error: 'invalid_token' }.to_json)
    end
  end

  describe '#initialize' do
    context 'with a recently connected account' do
      it 'does not refresh the token' do
        expect_any_instance_of(described_class).not_to receive(:refresh_token)
        described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account)
      end
    end

    context 'with an account connected more than 30 days ago' do
      let(:old_social_account) { create(:social_account, :threads, user: user, uid: threads_user_id, access_token: access_token, connected_at: 31.days.ago) }

      before { stub_token_refresh }

      it 'refreshes the token and persists to database' do
        described_class.new(app_id: app_id, app_secret: app_secret, social_account: old_social_account)

        old_social_account.reload
        expect(old_social_account.access_token).to eq(refreshed_token)
        expect(old_social_account.connected_at).to be_within(1.second).of(Time.current)
      end
    end

    # The token still works for weeks after it's due a refresh, so a failed one mustn't stop a post.
    context 'when token refresh fails for old account' do
      let(:old_social_account) { create(:social_account, :threads, user: user, uid: threads_user_id, access_token: access_token, connected_at: 31.days.ago) }

      before { stub_token_refresh(success: false) }

      it 'keeps the current token and reports the failure' do
        expect(Bugsnag).to receive(:notify).with(an_instance_of(RuntimeError))

        expect {
          described_class.new(app_id: app_id, app_secret: app_secret, social_account: old_social_account)
        }.not_to raise_error
        expect(old_social_account.reload.access_token).to eq(access_token)
      end
    end
  end

  describe 'post steps' do
    let(:threads_endpoint) { "#{described_class::THREADS_API_BASE}/#{threads_user_id}/threads" }
    let(:publish_endpoint) { "#{described_class::THREADS_API_BASE}/#{threads_user_id}/threads_publish" }
    let(:threads) { described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account) }

    describe '#create_media_container' do
      before do
        stub_request(:post, threads_endpoint)
          .with(query: hash_including(access_token: access_token))
          .to_return(status: 200, body: { id: 'container_123' }.to_json)
      end

      it 'creates a container and returns its ID' do
        id = threads.create_media_container(image_url: 'https://example.com/photo.jpg', caption: 'Test caption',
                                            topic_tag: 'photography', location_id: 'loc_123')

        expect(id).to eq('container_123')
        expect(WebMock).to(have_requested(:post, /#{threads_endpoint}/).with do |req|
          req.body.include?('text=Test') && req.body.include?('topic_tag=photography') && req.body.include?('location_id=loc_123')
        end)
      end
    end

    describe '#create_carousel_items' do
      let(:photos) { [{ url: 'https://example.com/1.jpg', alt_text: 'One' }, { url: 'https://example.com/2.jpg', alt_text: 'Two' }] }

      before do
        stub_request(:post, threads_endpoint)
          .with(query: hash_including(access_token: access_token))
          .to_return({ status: 200, body: { id: 'item_1' }.to_json }, { status: 200, body: { id: 'item_2' }.to_json })
      end

      # The carousel's own container can only be made once Meta has processed these.
      it 'creates a carousel item per photo, without waiting for them' do
        expect(threads.create_carousel_items(photos)).to eq(%w[item_1 item_2])
        expect(WebMock).to have_requested(:post, /#{threads_endpoint}/).with { |req| req.body.include?('is_carousel_item=true') }.twice
        expect(WebMock).not_to have_requested(:get, /graph\.threads\.net/)
      end

      it 'needs between 2 and 20 photos' do
        expect { threads.create_carousel_items(photos.take(1)) }.to raise_error(ArgumentError)
        expect { threads.create_carousel_items(photos * 11) }.to raise_error(ArgumentError)
      end
    end

    describe '#create_carousel_container' do
      it 'creates a carousel holding the given containers' do
        stub_request(:post, threads_endpoint)
          .with(query: hash_including(access_token: access_token))
          .to_return(status: 200, body: { id: 'carousel_123' }.to_json)

        expect(threads.create_carousel_container(children: %w[item_1 item_2], caption: 'Test caption')).to eq('carousel_123')
        expect(WebMock).to(have_requested(:post, /#{threads_endpoint}/).with do |req|
          req.body.include?('media_type=CAROUSEL') && req.body.include?('children=item_1%2Citem_2')
        end)
      end
    end

    describe '#container_status' do
      it "returns the container's status and Meta's explanation" do
        stub_request(:get, "#{described_class::THREADS_API_BASE}/container_123")
          .with(query: hash_including(fields: 'status,error_message', access_token: access_token))
          .to_return(status: 200, body: { status: 'ERROR', error_message: 'FAILED_DOWNLOADING_VIDEO' }.to_json)

        expect(threads.container_status('container_123')).to eq('code' => 'ERROR', 'error' => 'FAILED_DOWNLOADING_VIDEO')
      end
    end

    describe '#publish_container' do
      it 'publishes the container and returns the media ID' do
        stub_request(:post, publish_endpoint)
          .with(query: hash_including(access_token: access_token))
          .to_return(status: 200, body: { id: 'post_123' }.to_json)

        expect(threads.publish_container('container_123')['id']).to eq('post_123')
      end
    end
  end

  describe 'transient error handling' do
    let(:threads_endpoint) { "#{described_class::THREADS_API_BASE}/#{threads_user_id}/threads" }
    let(:threads) { described_class.new(app_id: app_id, app_secret: app_secret, social_account: social_account) }

    context 'when create_media_container returns a transient error' do
      before do
        stub_request(:post, threads_endpoint)
          .with(query: hash_including(access_token: access_token))
          .to_return(
            status: 400,
            body: { error: { message: 'An unexpected error has occurred.', type: 'OAuthException', is_transient: true, code: 2 } }.to_json
          )
      end

      it 'raises MetaTransientError' do
        expect {
          threads.create_media_container(image_url: 'https://example.com/photo.jpg', alt_text: 'Test', caption: 'Test')
        }.to raise_error(MetaTransientError, /Failed to create media container/)
      end
    end

    context 'when create_media_container returns a media download error' do
      before do
        stub_request(:post, threads_endpoint)
          .with(query: hash_including(access_token: access_token))
          .to_return(
            status: 400,
            body: { error: { message: 'An unknown error occurred', type: 'OAuthException', is_transient: false, code: 1, error_subcode: 2207052 } }.to_json
          )
      end

      it 'raises MetaMediaDownloadError' do
        expect {
          threads.create_media_container(image_url: 'https://example.com/photo.jpg', alt_text: 'Test', caption: 'Test')
        }.to raise_error(MetaMediaDownloadError, /Failed to create media container/)
      end
    end

    context 'when create_media_container returns a caption too long error' do
      before do
        stub_request(:post, threads_endpoint)
          .with(query: hash_including(access_token: access_token))
          .to_return(
            status: 400,
            body: { error: { message: 'Param text must be at most 500 characters long.', type: 'THApiException', code: 100 } }.to_json
          )
      end

      it 'raises MetaCaptionTooLongError' do
        expect {
          threads.create_media_container(image_url: 'https://example.com/photo.jpg', alt_text: 'Test', caption: 'x' * 501)
        }.to raise_error(MetaCaptionTooLongError, /Failed to create media container/)
      end
    end

    # Until the account is reconnected, every attempt gets the same answer.
    context 'when Meta refuses the access token' do
      before do
        stub_request(:post, threads_endpoint)
          .with(query: hash_including(access_token: access_token))
          .to_return(
            status: 400,
            body: { error: { message: 'Invalid token', type: 'OAuthException', is_transient: false, code: 190 } }.to_json
          )
      end

      it 'raises MetaAuthError' do
        expect {
          threads.create_media_container(image_url: 'https://example.com/photo.jpg', alt_text: 'Test', caption: 'Test')
        }.to raise_error(MetaAuthError, /Failed to create media container/)
      end
    end

    context 'when create_media_container returns a non-transient error' do
      before do
        stub_request(:post, threads_endpoint)
          .with(query: hash_including(access_token: access_token))
          .to_return(
            status: 400,
            body: { error: { message: 'Invalid parameter', type: 'OAuthException', is_transient: false, code: 100 } }.to_json
          )
      end

      it 'raises RuntimeError' do
        expect {
          threads.create_media_container(image_url: 'https://example.com/photo.jpg', alt_text: 'Test', caption: 'Test')
        }.to raise_error(RuntimeError, /Failed to create media container/)
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
