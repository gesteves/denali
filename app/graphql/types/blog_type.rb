module Types
  class BlogType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true
    field :tag_line, String, null: true
    field :formatted_tag_line, String, null: true
    field :plain_tag_line, String, null: true
    field :about, String, null: true
    field :plain_about, String, null: true
    field :formatted_about, String, null: true
    field :copyright, String, null: true
    field :instagram, String, null: true
    field :twitter, String, null: true
    field :email, String, null: true
    field :flickr, String, null: true
    field :facebook, String, null: true
    field :time_zone, String, null: true
    field :entries, [Types::EntryType], null: true do
      argument :page, Integer, default_value: 1, required: false
      argument :count, Integer, default_value: 1, required: false, prepare: -> (count, ctx) { [count, 100].min }
    end

    def entries(page:, count:)
      if count.present?
        object.entries.published.limit(count)
      elsif page.present?
        object.entries.published.page(page).per(object.posts_per_page)
      end
    end
  end
end
