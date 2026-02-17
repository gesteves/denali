require 'rails_helper'

RSpec.describe KnownAgents do
  let(:access_token) { 'test_api_key' }
  let(:known_agents) { described_class.new(access_token: access_token) }

  describe '#robots_txt' do
    let(:api_endpoint) { "#{described_class::API_URL}/robots-txts" }
    let(:robots_txt_response) do
      <<~ROBOTS
        User-agent: GPTBot
        Disallow: /

        User-agent: CCBot
        Disallow: /
      ROBOTS
    end

    context 'with successful response' do
      before do
        stub_request(:post, api_endpoint)
          .with(
            headers: {
              'Authorization' => "Bearer #{access_token}",
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: robots_txt_response)
      end

      it 'returns the robots.txt content' do
        result = known_agents.robots_txt
        expect(result).to include('User-agent: GPTBot')
        expect(result).to include('Disallow: /')
      end

      it 'sends default agent types' do
        known_agents.robots_txt
        expect(WebMock).to have_requested(:post, api_endpoint)
          .with(body: hash_including(
            agent_types: ['AI Data Scraper', 'Undocumented AI Agent'],
            disallow: '/'
          ))
      end

      it 'accepts custom agent types' do
        known_agents.robots_txt(agent_types: ['AI Search Crawler'], disallow: '/private')
        expect(WebMock).to have_requested(:post, api_endpoint)
          .with(body: hash_including(
            agent_types: ['AI Search Crawler'],
            disallow: '/private'
          ))
      end
    end

    context 'with failed response' do
      before do
        stub_request(:post, api_endpoint)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns nil' do
        result = known_agents.robots_txt
        expect(result).to be_nil
      end
    end

    context 'with blank access token' do
      let(:access_token) { '' }

      it 'returns nil without making a request' do
        result = known_agents.robots_txt
        expect(result).to be_nil
        expect(WebMock).not_to have_requested(:post, api_endpoint)
      end
    end

    context 'with nil access token' do
      let(:access_token) { nil }

      it 'returns nil without making a request' do
        result = known_agents.robots_txt
        expect(result).to be_nil
        expect(WebMock).not_to have_requested(:post, api_endpoint)
      end
    end
  end

  describe 'constants' do
    it 'has correct API URL' do
      expect(described_class::API_URL).to eq('https://api.knownagents.com')
    end

    it 'has correct default agent types' do
      expect(described_class::DEFAULT_AGENT_TYPES).to eq(['AI Data Scraper', 'Undocumented AI Agent'])
    end

    it 'has correct default disallow path' do
      expect(described_class::DEFAULT_DISALLOW).to eq('/')
    end
  end
end
