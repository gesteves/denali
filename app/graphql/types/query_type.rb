module Types
  class QueryType < Types::BaseObject
    field :blog, Types::BlogType, null: false
    field :entry, Types::EntryType, null: false do
      argument :url, String, required: true
    end
    field :entries, [Types::EntryType], null: true do
      argument :page, Integer, default_value: 1, required: false
      argument :count, Integer, default_value: 10, required: false, prepare: -> (count, ctx) { [count, 100].min }
    end

    def blog
      Blog.first
    end

    def entry(url:)
      Entry.find_by_url(url: url)
    end

    def entries(page:, count:)
      Entry.published.page(page).per(count)
    end
  end
end
