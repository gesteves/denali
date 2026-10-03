require 'rails_helper'

# AtProto is shared by Bluesky and StandardSite; this exercises it through a
# minimal includer so its own contract is pinned down independently of either.
RSpec.describe AtProto do
  let(:client_class) do
    Class.new do
      include AtProto

      def initialize
        configure_at_proto(base_url: 'https://pds.example/', identifier: 'me.example', password: 'app-password')
      end

      def at_proto_label = 'test'

      public :put_record, :delete_record, :access_token, :did
    end
  end
  let(:client) { client_class.new }

  let(:session_url) { 'https://pds.example/xrpc/com.atproto.server.createSession' }
  let(:put_url) { 'https://pds.example/xrpc/com.atproto.repo.putRecord' }
  let(:delete_url) { 'https://pds.example/xrpc/com.atproto.repo.deleteRecord' }

  def stub_session(token: 'token-1', did: 'did:plc:me')
    stub_request(:post, session_url).to_return(status: 200, body: { accessJwt: token, did: did }.to_json)
  end

  describe '.seconds_between_writes' do
    # Half of 5,000 points an hour at 3 points a record.
    it 'spaces writes to stay inside half the hourly budget' do
      expect(described_class.seconds_between_writes).to be_within(0.01).of(3600.0 / 833)
    end
  end

  describe 'sessions' do
    around do |example|
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original
    end

    it 'opens one session and reuses its token and DID' do
      stub_session

      expect(client.access_token).to eq('token-1')
      expect(client_class.new.did).to eq('did:plc:me')
      expect(a_request(:post, session_url)).to have_been_made.once
    end

    it 'treats a refused handle or password as an authentication error' do
      stub_request(:post, session_url).to_return(status: 401, body: 'nope')
      expect { client.access_token }.to raise_error(AtProto::AuthenticationError)
    end

    it 'treats a PDS that is down as a connection error' do
      stub_request(:post, session_url).to_return(status: 502, body: 'bad gateway')
      expect { client.access_token }.to raise_error(AtProto::ConnectionError)
    end

    it 'treats a network failure as a connection error' do
      stub_request(:post, session_url).to_raise(Errno::ECONNREFUSED)
      expect { client.access_token }.to raise_error(AtProto::ConnectionError, /pds\.example/)
    end

    # A revoked token or a changed app password would otherwise fail every
    # attempt for the rest of the cached token's hour.
    it 'starts a new session once when the PDS rejects the token' do
      stub_request(:post, session_url).to_return(
        { status: 200, body: { accessJwt: 'stale', did: 'did:plc:me' }.to_json },
        { status: 200, body: { accessJwt: 'fresh', did: 'did:plc:me' }.to_json }
      )
      stub_request(:post, put_url).with(headers: { 'Authorization' => 'Bearer stale' }).to_return(status: 401)
      stub_request(:post, put_url).with(headers: { 'Authorization' => 'Bearer fresh' })
        .to_return(status: 200, body: { uri: 'at://x', cid: 'bafy' }.to_json)

      expect(client.put_record(collection: 'app.bsky.feed.post', rkey: 'abc', record: {})['cid']).to eq('bafy')
    end
  end

  describe '#put_record' do
    before { stub_session }

    # A reply names its parent by cid, so a write without one is a failure.
    it 'refuses a response with no cid' do
      stub_request(:post, put_url).to_return(status: 200, body: { uri: 'at://x' }.to_json)
      expect { client.put_record(collection: 'c', rkey: 'r', record: {}) }.to raise_error(/no cid/)
    end

    it 'sends validate only when asked' do
      stub_request(:post, put_url).to_return(status: 200, body: { uri: 'at://x', cid: 'bafy' }.to_json)

      client.put_record(collection: 'c', rkey: 'r', record: {}, validate: false)

      expect(a_request(:post, put_url).with { |req| JSON.parse(req.body)['validate'] == false }).to have_been_made
    end

    describe 'rate limits' do
      def limited_with(reset)
        stub_request(:post, put_url).to_return(status: 429, headers: { 'ratelimit-reset' => reset.to_s })
        client.put_record(collection: 'c', rkey: 'r', record: {})
      rescue AtProto::RateLimitedError => e
        e.retry_after
      end

      it 'waits until the PDS said it would reset' do
        freeze_time { expect(limited_with((Time.now + 300).to_i)).to eq(300) }
      end

      # A missing, past or absurd header still has to give a sane delay.
      it 'waits at least a minute and at most an hour' do
        freeze_time do
          expect(limited_with(0)).to eq(60)
          expect(limited_with((Time.now - 30).to_i)).to eq(60)
          expect(limited_with((Time.now + 86_400).to_i)).to eq(3600)
        end
      end
    end
  end

  describe '#delete_record' do
    before { stub_session }

    it 'reports success' do
      stub_request(:post, delete_url).to_return(status: 200, body: '{}')
      expect(client.delete_record(collection: 'c', rkey: 'r')).to be true
    end

    # A backfill's prune step deletes many records, and one failure mustn't stop it.
    it 'answers false rather than raising when the delete fails' do
      stub_request(:post, delete_url).to_return(status: 500, body: 'oops')
      expect(client.delete_record(collection: 'c', rkey: 'r')).to be false
    end

    it 'answers false when the PDS cannot be reached' do
      stub_request(:post, delete_url).to_raise(Net::ReadTimeout)
      expect(client.delete_record(collection: 'c', rkey: 'r')).to be false
    end

    # "Come back later" isn't a failed delete.
    it 'still raises when rate limited' do
      stub_request(:post, delete_url).to_return(status: 429)
      expect { client.delete_record(collection: 'c', rkey: 'r') }.to raise_error(AtProto::RateLimitedError)
    end
  end
end
