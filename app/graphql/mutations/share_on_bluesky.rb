module Mutations
  class ShareOnBluesky < BaseMutation
    field :entry, Types::EntryType, null: false
    field :errors, [String], null: false

    argument :input, Types::ShareOnBlueskyInput, required: true

    def resolve(input:)
      url = input[:url]

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
