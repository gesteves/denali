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
    field :search, [Types::EntryType], null: true do
      argument :term, String, required: true
      argument :page, Integer, default_value: 1, required: false
      argument :count, Integer, default_value: 10, required: false, prepare: -> (count, ctx) { [count, 100].min }
    end
    field :cameras, [Types::CameraType], null: true do
      argument :page, Integer, default_value: 1, required: false
      argument :count, Integer, default_value: 10, required: false, prepare: -> (count, ctx) { [count, 100].min }
    end
    field :lenses, [Types::LensType], null: true do
      argument :page, Integer, default_value: 1, required: false
      argument :count, Integer, default_value: 10, required: false, prepare: -> (count, ctx) { [count, 100].min }
    end
    field :films, [Types::FilmType], null: true do
      argument :page, Integer, default_value: 1, required: false
      argument :count, Integer, default_value: 10, required: false, prepare: -> (count, ctx) { [count, 100].min }
    end

    def blog
      Blog.first
    end

    def entry(url:)
      Entry.find_by_url(url: url)
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError, "Can't find entry with URL #{url}"
    end

    def entries(page:, count:)
      Entry.published.page(page).per(count)
    end

    def search(term:, page:, count:)
      results = Entry.published_search(term, page, count)
      total_count = results.results.total
      Kaminari.paginate_array(results.records, total_count: total_count).page(page).per(count)
    end

    def cameras(page:, count:)
      Camera.all.page(page).per(count)
    end

    def lenses(page:, count:)
      Lens.all.page(page).per(count)
    end

    def films(page:, count:)
      Film.all.page(page).per(count)
    end
  end
end
