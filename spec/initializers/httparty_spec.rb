require 'rails_helper'

RSpec.describe 'HTTParty defaults' do
  # Net::HTTP's own defaults are a minute each, long enough for a hung API to
  # hold a Puma or Sidekiq thread for minutes.
  it 'gives calls without their own timeout a 30-second one' do
    expect(HTTParty::Basement.default_options[:timeout]).to eq(30)
  end

  it 'applies to module-level calls' do
    stub_request(:get, 'https://example.com/')
    expect(HTTParty::Request).to receive(:new).with(anything, anything, hash_including(timeout: 30)).and_call_original

    HTTParty.get('https://example.com/')
  end

  it 'lets a call set a longer one' do
    stub_request(:get, 'https://example.com/')
    expect(HTTParty::Request).to receive(:new).with(anything, anything, hash_including(timeout: 120)).and_call_original

    HTTParty.get('https://example.com/', timeout: 120)
  end
end
