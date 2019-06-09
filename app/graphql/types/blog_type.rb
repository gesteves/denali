module Types
  class BlogType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true, description: "The title of the blog"
    field :tag_line, String, null: true, description: "A short description of the blog, as entered by the author in Markdown"
    field :formatted_tag_line, String, null: true, description: "A short description of the blog, formatted in HTML"
    field :plain_tag_line, String, null: true, description: "A short description of the blog, in plain text"
    field :about, String, null: true, description: "A full description of the blog, as entered by the author in Markdown"
    field :plain_about, String, null: true, description: "A full description of the blog, in plain text"
    field :formatted_about, String, null: true, description: "A full description of the blog, formatted in HTML"
    field :copyright, String, null: true, description: "Copyright info for the blog"
    field :instagram, String, null: true, description: "Instagram account for the blog"
    field :twitter, String, null: true, description: "Twitter account for the blog"
    field :email, String, null: true, description: "Contact email for the blog"
    field :flickr, String, null: true, description: "Flickr account for the blog"
    field :facebook, String, null: true, description: "Facebook account for the blog"
    field :time_zone, String, null: true, description: "Time zone the blog publishes in"
    field :entries, [Types::EntryType], null: true, description: "The list of published entries in this blog" do
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
