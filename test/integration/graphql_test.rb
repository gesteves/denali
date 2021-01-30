require "test_helper"

class GraphqlTest < ActionDispatch::IntegrationTest
  test 'graphql should load entries by url' do
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

    result = DenaliSchema.execute(query_string, variables: { url: entry_url })
    assert_equal 'Peppers at Eastern Market, Washington, DC. July 2nd, 2011.', result['data']['entry']['title']
    assert_equal 'eastern-market-peppers', result['data']['entry']['slug']
    assert_equal 'published', result['data']['entry']['status']
  end
end
