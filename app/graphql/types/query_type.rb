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
      url = Rails.application.routes.recognize_path(url)
      if url[:controller] == 'entries' && url[:action] == 'show' && url[:id].present?
        Entry.published.find(url[:id])
      elsif url[:controller] == 'entries' && url[:action] == 'preview' && url[:preview_hash].present?
        Entry.where(preview_hash: url[:preview_hash]).limit(1).first
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    def entries(page:, count:)
      Entry.published.page(page).per(count)
    end
  end
end
