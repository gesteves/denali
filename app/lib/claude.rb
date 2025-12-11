require 'httparty'
require 'json'

# Represents a client for interacting with the Claude API.
class Claude
  ANTHROPIC_API_URL = 'https://api.anthropic.com/v1'

  # Initializes a new instance of the Claude class.
  def initialize
    @api_key = ENV['ANTHROPIC_API_KEY']
  end

  # Sends a request to the Claude Messages API and returns the response as a JSON object.
  #
  # @param body [Hash] The body of the request to the Claude API.
  # @return [Hash] The response as a JSON object.
  def create_message(body)
    options = {
      headers: {
        "x-api-key" => @api_key,
        "anthropic-version" => "2023-06-01",
        "Content-Type" => "application/json"
      },
      body: body.to_json,
      timeout: 120
    }
    response = HTTParty.post("#{ANTHROPIC_API_URL}/messages", options)
    if response.success?
      response.parsed_response
    else
      raise "Claude API request failed with status code #{response.code}: #{response.parsed_response['error']['message']}"
    end
  end
end
