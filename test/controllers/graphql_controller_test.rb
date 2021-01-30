require 'test_helper'

class GraphqlControllerTest < ActionController::TestCase
  test 'can get entries by url' do
    entry = entries(:peppers)
    entry_url = entry.permalink_url

    query_string = <<-GRAPHQL
      query ($url: String!) {
        entry(url: $url) {
          title
          slug
          status
        }
      }
    GRAPHQL

    post :execute, params: { query: query_string, variables: { url: entry_url } }

    assert_response :success
    result = JSON.parse(@response.body)
    assert_equal 'Peppers at Eastern Market, Washington, DC. July 2nd, 2011.', result['data']['entry']['title']
    assert_equal 'eastern-market-peppers', result['data']['entry']['slug']
    assert_equal 'published', result['data']['entry']['status']
  end
end
