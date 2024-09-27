module Mutations
  class ShareOnBluesky < BaseMutation
    argument :url, String, required: true

    field :entry, Types::EntryType, null: false
    field :errors, [String], null: false

    def resolve(url:)
      begin
        entry = Entry.find_by_url(url: url)
        BlueskyWorker.perform_async(entry.id, entry.bluesky_caption)
        {
          entry: entry,
          errors: []
        }
      rescue => e
        {
          entry: nil,
          errors: [e.message]
        }
      end
    end
  end
end
