module Types
  class EntryPageType < Types::BaseObject
    field :entries, [Types::EntryType], null: false, description: "The list of entries"
    field :total_count, Integer, null: false, description: "Total number of entries across all pages"
    field :page, Integer, null: false, description: "Current page number"
    field :total_pages, Integer, null: false, description: "Total number of pages"
    field :has_next_page, Boolean, null: false, description: "Whether there are more pages after the current one"
  end
end
