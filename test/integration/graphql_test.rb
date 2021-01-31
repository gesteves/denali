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

  test 'graphql should return instagram crops for entry' do
    entry = entries(:peppers)
    entry_url = entry.permalink_url
    set_up_images(entry)

    query_string = <<-GRAPHQL
      query ($url: String!) {
        entry(url: $url) {
          photos {
            instagramUrl
            instagramStoryUrl
          }
        }
      }
    GRAPHQL

    result = DenaliSchema.execute(query_string, variables: { url: entry_url })
    assert result['data']['entry']['photos'].present?
    assert_equal 1, result['data']['entry']['photos'].size
    assert result['data']['entry']['photos'][0]['instagramUrl'].present?
    assert result['data']['entry']['photos'][0]['instagramStoryUrl'].present?
  end

  test 'graphql should return recent entries' do
    set_up_all_images

    query_string = <<-GRAPHQL
      query($count: Int) {
        blog {
          name
          entries(count: $count) {
            status
            photos {
              thumbnailUrls
            }
          }
        }
      }
    GRAPHQL

    result = DenaliSchema.execute(query_string, variables: { count: 10 })
    assert_equal 'All-Encompassing Trip', result['data']['blog']['name']
    assert result['data']['blog']['entries'].present?
    assert_equal 2, result['data']['blog']['entries'].size
    assert result['data']['blog']['entries'].all? { |e| e['status'] == 'published' }
    assert result['data']['blog']['entries'][0]['photos'][0]['thumbnailUrls'].present?
  end
end
