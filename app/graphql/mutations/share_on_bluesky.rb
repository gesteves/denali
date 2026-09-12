module Mutations
  class ShareOnBluesky < BaseMutation
    argument :url, String, required: true

    field :entry, Types::EntryType, null: true
    field :errors, [String], null: false

    def resolve(url:)
      entry = Entry.find_by_url(url: url)
      caption = entry.bluesky_caption
      unless Bluesky.valid_post_length?(caption)
        return { entry: nil, errors: ["The caption is empty or too long for Bluesky"] }
      end

      BlueskyJob.perform_async(entry.id, caption, nil, nil, Bluesky.new_tid)
      { entry: entry, errors: [] }
    rescue ActiveRecord::RecordNotFound
      raise GraphQL::ExecutionError, "Entry not found"
    rescue StandardError => e
      Rails.logger.error("ShareOnBluesky failed: #{e.message}")
      { entry: nil, errors: ["Something went wrong"] }
    end
  end
end
