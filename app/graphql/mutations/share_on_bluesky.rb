module Mutations
  class ShareOnBluesky < BaseMutation
    argument :url, String, required: true

    field :entry, Types::EntryType, null: true
    field :errors, [String], null: false

    def resolve(url:)
      entry = Entry.find_by_url(url: url)

      if entry.present?
        BlueskyWorker.perform_async(entry.id, entry.bluesky_caption)

        {
          entry: entry,
          errors: []
        }
      else
        {
          entry: nil,
          errors: ["Entry not found for the provided URL."]
        }
      end
    end
  end
end
