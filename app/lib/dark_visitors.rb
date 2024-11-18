class DarkVisitors
  DARK_VISITORS_API_URL = "https://api.darkvisitors.com".freeze
  DEFAULT_AGENT_TYPES = ["AI Data Scraper", "Undocumented AI Agent"].freeze
  DEFAULT_DISALLOW = "/".freeze

  # Initializes the DarkVisitors instance by fetching the robots.txt data from the API.
  def initialize(access_token:)
    @access_token = access_token
  end

  # Fetches the robots.txt data from the DarkVisitors API.
  # @return [String] The robots.txt data as a string.
  def robots_txt(agent_types: DEFAULT_AGENT_TYPES, disallow: DEFAULT_DISALLOW)
    return if @access_token.blank?

    body = {
      agent_types: agent_types,
      disallow: disallow
    }

    headers = {
      "Authorization" => "Bearer #{@access_token}",
      "Content-Type" => "application/json"
    }

    response = HTTParty.post("#{DARK_VISITORS_API_URL}/robots-txts", headers: headers, body: body.to_json)
    return unless response.success?

    response.body
  end
end
