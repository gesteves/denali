require 'httparty'
require 'json'

# Represents a client for interacting with the ChatGPT API.
class Chatgpt
  OPENAI_API_URL = 'https://api.openai.com/v1'

  # Initializes a new instance of the ChatgptClient class.
  def initialize
    @api_key = ENV['OPENAI_API_KEY']
  end

  # Sends a request to the ChatGPT API and returns the response as a JSON object.
  #
  # @param body [Hash] The body of the request to the ChatGPT API.
  # @return [Hash] The response as a JSON object.
  def create_response(body)
    options = {
      headers: { "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json" },
      body: body.to_json,
      timeout: 120
    }
    response = HTTParty.post("#{OPENAI_API_URL}/responses", options)
    if response.success?
      response.parsed_response
    else
      raise "ChatGPT API request failed with status code #{response.code}: #{response.parsed_response['error']['message']}"
    end
  end
end
