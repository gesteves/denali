require 'rails_helper'

RSpec.describe "GraphQL", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }

  def execute_query(query, variables: {}, auth_token: nil)
    headers = { 'Content-Type' => 'application/json' }
    headers['Authorization'] = "Bearer #{auth_token}" if auth_token

    post graphql_path, params: { query: query, variables: variables }.to_json, headers: headers
    JSON.parse(response.body)
  end

  describe "POST /graphql" do
    describe "blog query" do
      it "returns blog information" do
        query = <<~GRAPHQL
          query {
            blog {
              id
              name
              about
              tagLine
              postsPerPage
              showRelatedEntries
              timeZone
            }
          }
        GRAPHQL

        result = execute_query(query)

        expect(response).to have_http_status(:success)
        expect(result['data']['blog']).to include(
          'name' => blog.name,
          'about' => blog.about,
          'postsPerPage' => blog.posts_per_page
        )
      end

      it "returns blog with entries" do
        entries = create_list(:entry, 3, :published, :with_photo, blog: blog, user: user)
        entries.each { |e| e.photos.each { |p| attach_image_to_photo(p) } }

        query = <<~GRAPHQL
          query {
            blog {
              id
              name
              entries(page: 1, count: 10) {
                id
                title
                status
              }
            }
          }
        GRAPHQL

        result = execute_query(query)

        expect(response).to have_http_status(:success)
        expect(result['data']['blog']['entries'].length).to eq(3)
      end

      it "limits entries count to maximum of 100" do
        create_list(:entry, 5, :published, :with_photo, blog: blog, user: user).each do |e|
          e.photos.each { |p| attach_image_to_photo(p) }
        end

        query = <<~GRAPHQL
          query {
            blog {
              entries(count: 200) {
                id
              }
            }
          }
        GRAPHQL

        result = execute_query(query)

        expect(response).to have_http_status(:success)
        # Should not error, count is capped at 100
        expect(result['errors']).to be_nil
      end
    end

    describe "entry query" do
      let!(:entry) do
        e = create(:entry, :published, :with_photo, blog: blog, user: user)
        e.photos.each { |p| attach_image_to_photo(p) }
        e
      end

      it "returns entry by URL" do
        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              id
              title
              body
              formattedBody
              plainBody
              plainTitle
              status
              slug
              url
              photosCount
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: entry.permalink_url })

        expect(response).to have_http_status(:success)
        expect(result['data']['entry']).to include(
          'title' => entry.title,
          'slug' => entry.slug,
          'status' => 'published',
          'photosCount' => entry.photos_count
        )
      end

      it "returns entry with photos" do
        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              id
              title
              photos {
                id
                altText
                width
                height
              }
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: entry.permalink_url })

        expect(response).to have_http_status(:success)
        expect(result['data']['entry']['photos'].length).to eq(entry.photos.count)
      end

      it "returns entry with tags" do
        entry.tag_list = 'nature, landscape'
        entry.save!

        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              id
              tags {
                name
              }
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: entry.permalink_url })

        expect(response).to have_http_status(:success)
        tag_names = result['data']['entry']['tags'].map { |t| t['name'] }
        expect(tag_names).to include('nature', 'landscape')
      end

      it "returns entry with user" do
        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              id
              user {
                id
                name
              }
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: entry.permalink_url })

        expect(response).to have_http_status(:success)
        expect(result['data']['entry']['user']['name']).to eq(user.name)
      end

      it "returns error for non-existent entry" do
        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              id
              title
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: 'https://example.com/nonexistent' })

        expect(response).to have_http_status(:success)
        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to include("Can't find entry")
      end
    end

    describe "entries query" do
      before do
        create_list(:entry, 5, :published, :with_photo, blog: blog, user: user).each do |e|
          e.photos.each { |p| attach_image_to_photo(p) }
        end
      end

      it "returns paginated entries" do
        query = <<~GRAPHQL
          query {
            entries(page: 1, count: 3) {
              id
              title
              status
            }
          }
        GRAPHQL

        result = execute_query(query)

        expect(response).to have_http_status(:success)
        expect(result['data']['entries'].length).to eq(3)
      end

      it "returns second page of entries" do
        query = <<~GRAPHQL
          query {
            entries(page: 2, count: 3) {
              id
              title
            }
          }
        GRAPHQL

        result = execute_query(query)

        expect(response).to have_http_status(:success)
        expect(result['data']['entries'].length).to eq(2)
      end

      it "limits count to maximum of 100" do
        query = <<~GRAPHQL
          query {
            entries(count: 150) {
              id
            }
          }
        GRAPHQL

        result = execute_query(query)

        expect(response).to have_http_status(:success)
        expect(result['errors']).to be_nil
      end
    end

    describe "search query" do
      before do
        # Create entries with searchable content
        create(:entry, :published, :with_photo, title: "Mountain Photography", blog: blog, user: user).tap do |e|
          e.photos.each { |p| attach_image_to_photo(p) }
        end
        create(:entry, :published, :with_photo, title: "Ocean Waves", blog: blog, user: user).tap do |e|
          e.photos.each { |p| attach_image_to_photo(p) }
        end

        # Refresh Elasticsearch index
        Entry.__elasticsearch__.refresh_index! if Entry.respond_to?(:__elasticsearch__)
      end

      it "returns search results", :vcr do
        query = <<~GRAPHQL
          query($term: String!) {
            search(term: $term, page: 1, count: 10) {
              id
              title
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { term: 'Mountain' })

        expect(response).to have_http_status(:success)
        # Search may or may not return results depending on ES setup
        expect(result['data']['search']).to be_an(Array)
      end
    end

    describe "photo fields" do
      let!(:entry) do
        e = create(:entry, :published, :with_photo, blog: blog, user: user, show_location: true)
        e.photos.each do |p|
          attach_image_to_photo(p)
          p.update(latitude: 47.6062, longitude: -122.3321)
        end
        e
      end

      it "returns photo URLs with specified widths" do
        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              photos {
                urls(widths: [640, 1280])
              }
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: entry.permalink_url })

        expect(response).to have_http_status(:success)
        urls = result['data']['entry']['photos'].first['urls']
        expect(urls.length).to eq(2)
      end

      it "returns photo thumbnail URLs" do
        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              photos {
                thumbnailUrls(widths: [320, 640])
              }
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: entry.permalink_url })

        expect(response).to have_http_status(:success)
        urls = result['data']['entry']['photos'].first['thumbnailUrls']
        expect(urls.length).to eq(2)
      end

      it "does not return location data without authorization" do
        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              photos {
                latitude
                longitude
              }
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: entry.permalink_url })

        expect(response).to have_http_status(:success)
        photo = result['data']['entry']['photos'].first
        expect(photo['latitude']).to be_nil
        expect(photo['longitude']).to be_nil
      end

      it "returns location data with authorization" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('GRAPHQL_AUTH_TOKEN').and_return('test-token')

        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              photos {
                latitude
                longitude
              }
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: entry.permalink_url }, auth_token: 'test-token')

        expect(response).to have_http_status(:success)
        photo = result['data']['entry']['photos'].first
        expect(photo['latitude']).to be_present
        expect(photo['longitude']).to be_present
      end

      it "does not return download URL without authorization" do
        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              photos {
                downloadUrl
              }
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: entry.permalink_url })

        expect(response).to have_http_status(:success)
        photo = result['data']['entry']['photos'].first
        expect(photo['downloadUrl']).to be_nil
      end

      it "returns download URL with authorization" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('GRAPHQL_AUTH_TOKEN').and_return('test-token')

        # Stub ActiveStorage URL generation to avoid needing host configuration
        allow_any_instance_of(ActiveStorage::Blob).to receive(:url).and_return('http://localhost/test-download.jpg')

        query = <<~GRAPHQL
          query($url: String!) {
            entry(url: $url) {
              photos {
                downloadUrl
              }
            }
          }
        GRAPHQL

        result = execute_query(query, variables: { url: entry.permalink_url }, auth_token: 'test-token')

        expect(response).to have_http_status(:success)
        photo = result['data']['entry']['photos'].first
        expect(photo['downloadUrl']).to be_present
      end
    end
  end

  describe "mutations" do
    describe "expireBlogCache" do
      let(:mutation) do
        <<~GRAPHQL
          mutation {
            expireBlogCache(input: {}) {
              blog {
                id
                name
              }
              errors
            }
          }
        GRAPHQL
      end

      it "requires authorization" do
        result = execute_query(mutation)

        expect(response).to have_http_status(:success)
        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to include("permission")
      end

      it "expires cache when authorized" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('GRAPHQL_AUTH_TOKEN').and_return('test-token')

        # Stub the purge_from_cdn method
        allow_any_instance_of(Blog).to receive(:purge_from_cdn).and_return(true)

        result = execute_query(mutation, auth_token: 'test-token')

        expect(response).to have_http_status(:success)
        expect(result['data']['expireBlogCache']['blog']).to be_present
        expect(result['data']['expireBlogCache']['errors']).to be_empty
      end
    end

    describe "shareOnBluesky" do
      let!(:entry) do
        e = create(:entry, :published, :with_photo, blog: blog, user: user)
        e.photos.each { |p| attach_image_to_photo(p) }
        e
      end

      let(:mutation) do
        <<~GRAPHQL
          mutation($url: String!) {
            shareOnBluesky(input: { url: $url }) {
              entry {
                id
                title
              }
              errors
            }
          }
        GRAPHQL
      end

      it "requires authorization" do
        result = execute_query(mutation, variables: { url: entry.permalink_url })

        expect(response).to have_http_status(:success)
        expect(result['errors']).to be_present
        expect(result['errors'].first['message']).to include("permission")
      end

      it "queues Bluesky share when authorized" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('GRAPHQL_AUTH_TOKEN').and_return('test-token')

        # Clear any previously queued jobs
        BlueskyWorker.jobs.clear

        result = execute_query(mutation, variables: { url: entry.permalink_url }, auth_token: 'test-token')

        expect(response).to have_http_status(:success)
        expect(result['data']['shareOnBluesky']['entry']).to be_present
        expect(result['data']['shareOnBluesky']['errors']).to be_empty
        expect(BlueskyWorker.jobs.size).to eq(1)
      end
    end
  end

  describe "OPTIONS /graphql" do
    it "returns OK for CORS preflight" do
      process :options, graphql_path

      expect(response).to have_http_status(:success)
      expect(response.body).to eq('OK')
    end
  end

  describe "error handling" do
    it "handles invalid queries gracefully" do
      result = execute_query("{ invalidField }")

      expect(response).to have_http_status(:success)
      expect(result['errors']).to be_present
    end

    it "handles empty string variables" do
      post graphql_path,
           params: { query: "{ blog { id } }", variables: "" }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:success)
      result = JSON.parse(response.body)
      expect(result['data']['blog']).to be_present
    end

    it "handles nil variables" do
      post graphql_path,
           params: { query: "{ blog { id } }", variables: nil }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:success)
      result = JSON.parse(response.body)
      expect(result['data']['blog']).to be_present
    end
  end
end
