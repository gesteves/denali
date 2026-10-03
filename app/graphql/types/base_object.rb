module Types
  class BaseObject < GraphQL::Schema::Object
    # Pagination arguments end up in LIMIT/OFFSET and Elasticsearch's `from`,
    # where zero or negative values raise, so they're clamped to sane ranges.
    PREPARE_PAGE = ->(page, _ctx) { [page, 1].max }
    PREPARE_COUNT = ->(count, _ctx) { count.clamp(1, 100) }
  end
end
