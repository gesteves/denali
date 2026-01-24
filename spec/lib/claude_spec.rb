require 'rails_helper'

RSpec.describe Claude do
  let(:api_key) { 'test_api_key' }
  let(:claude) { described_class.new }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(api_key)
  end

  describe '#create_message' do
    let(:api_endpoint) { 'https://api.anthropic.com/v1/messages' }
    let(:request_body) do
      {
        model: 'claude-haiku-4-5',
        max_tokens: 1024,
        messages: [
          { role: 'user', content: 'Hello, Claude!' }
        ]
      }
    end

    context 'with successful response' do
      let(:response_body) do
        {
          'id' => 'msg_123',
          'type' => 'message',
          'role' => 'assistant',
          'content' => [
            { 'type' => 'text', 'text' => 'Hello! How can I help you today?' }
          ],
          'model' => 'claude-haiku-4-5',
          'stop_reason' => 'end_turn',
          'usage' => {
            'input_tokens' => 10,
            'output_tokens' => 25
          }
        }
      end

      before do
        stub_request(:post, api_endpoint)
          .with(
            headers: {
              'x-api-key' => api_key,
              'anthropic-version' => '2023-06-01',
              'Content-Type' => 'application/json'
            }
          )
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'sends request with correct headers' do
        claude.create_message(request_body)
        expect(WebMock).to have_requested(:post, api_endpoint)
          .with(headers: { 'x-api-key' => api_key })
      end

      it 'returns parsed response' do
        response = claude.create_message(request_body)
        expect(response['id']).to eq('msg_123')
        expect(response['content'].first['text']).to eq('Hello! How can I help you today?')
      end

      it 'sends request body as JSON' do
        claude.create_message(request_body)
        expect(WebMock).to have_requested(:post, api_endpoint)
          .with(body: request_body.to_json)
      end
    end

    context 'with failed response' do
      before do
        stub_request(:post, api_endpoint)
          .to_return(
            status: 400,
            body: {
              'type' => 'error',
              'error' => {
                'type' => 'invalid_request_error',
                'message' => 'Invalid API key'
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises an error with the message' do
        expect {
          claude.create_message(request_body)
        }.to raise_error(RuntimeError, /Claude API request failed with status code 400/)
      end
    end

    context 'with rate limit error' do
      before do
        stub_request(:post, api_endpoint)
          .to_return(
            status: 429,
            body: {
              'type' => 'error',
              'error' => {
                'type' => 'rate_limit_error',
                'message' => 'Rate limit exceeded'
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises an error' do
        expect {
          claude.create_message(request_body)
        }.to raise_error(RuntimeError, /Claude API request failed with status code 429/)
      end
    end
  end

  describe 'ANTHROPIC_API_URL' do
    it 'is set to the correct endpoint' do
      expect(described_class::ANTHROPIC_API_URL).to eq('https://api.anthropic.com/v1')
    end
  end
end
