module Types
  class QueryType < Types::BaseObject
    field :blog, Types::BlogType, null: false
    field :entry, Types::EntryType, null: false do
      argument :url, String, required: true
    end
    field :entries, Types::EntryPageType, null: false do
      argument :page, Integer, default_value: 1, required: false
      argument :count, Integer, default_value: 10, required: false, prepare: -> (count, ctx) { [count, 100].min }
    end
    field :search, Types::EntryPageType, null: false do
      argument :term, String, required: true
      argument :page, Integer, default_value: 1, required: false
      argument :count, Integer, default_value: 10, required: false, prepare: -> (count, ctx) { [count, 100].min }
    end

    def blog
      Blog.first
    end

    def entry(url:)
      Entry.with_graphql_includes.find(Entry.find_by_url(url: url).id)
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError, "Can't find entry with URL #{url}"
    end

    def entries(page:, count:)
      entries = Entry.with_graphql_includes.published.page(page).per(count)
      build_entry_page(entries, page)
    end

    def search(term:, page:, count:)
      results = Entry.published_search(term, page, count)
      total_count = results.results.total
      entries = Kaminari.paginate_array(results.records, total_count: total_count).page(page).per(count)
      build_entry_page(entries, page)
    end

    private

    def build_entry_page(entries, page)
      {
        entries: entries,
        total_count: entries.total_count,
        page: page,
        total_pages: entries.total_pages,
        has_next_page: page < entries.total_pages
      }
    end
  end
end
