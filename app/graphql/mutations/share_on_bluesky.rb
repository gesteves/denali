module Mutations
  class ShareOnBluesky < BaseMutation
    argument :url, String, required: true

    field :entry, Types::EntryType, null: true
    field :errors, [String], null: false

    def resolve(url:)
      begin
        entry = Entry.find_by_url(url: url)
        BlueskyJob.perform_async(entry.id, entry.bluesky_caption)
        {
          entry: entry,
          errors: []
        }
      rescue => e
        {
          entry: nil,
          errors: [e]
        }
      end
    end
  end
end
