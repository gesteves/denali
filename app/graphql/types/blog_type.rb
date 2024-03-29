module Types
  class BlogType < Types::BaseObject
    field :id, ID, null: false
    field :about, String, null: true, description: "A full description of the blog, as entered by the author in Markdown"
    field :additional_meta_tags, String, null: true, description: "Additional meta tags"
    field :analytics_body, String, null: true, description: "Analytics script inserted at the end of the body element"
    field :analytics_head, String, null: true, description: "Analytics script inserted at the end of the head element"
    field :copyright, String, null: true, description: "Copyright info for the blog"
    field :formatted_about, String, null: true, description: "A full description of the blog, formatted in HTML"
    field :formatted_tag_line, String, null: true, description: "A short description of the blog, formatted in HTML"
    field :header_logo_svg, String, null: true, description: "SVG for the main header logo"
    field :map_style, String, null: true, description: "Style of the maps in the map view"
    field :meta_description, String, null: true, description: "Content of the description meta tag"
    field :name, String, null: true, description: "The title of the blog"
    field :plain_about, String, null: true, description: "A full description of the blog, in plain text"
    field :plain_tag_line, String, null: true, description: "A short description of the blog, in plain text"
    field :posts_per_page, Int, null: true, description: "The number of entries to show per page"
    field :show_related_entries, Boolean, null: true, description: "Show related entries in entry pages"
    field :show_search, Boolean, null: true, description: "Enable search on the site"
    field :tag_line, String, null: true, description: "A short description of the blog, as entered by the author in Markdown"
    field :time_zone, String, null: true, description: "Time zone the blog publishes in"
    field :entries, [Types::EntryType], null: true, description: "The list of published entries in this blog" do
      argument :page, Integer, default_value: 1, required: false
      argument :count, Integer, default_value: 10, required: false, prepare: -> (count, ctx) { [count, 100].min }
    end

    def entries(page:, count:)
      object.entries.includes(:user, photos: [:image_attachment, :image_blob, :camera, :lens, :film], taggings: :tag).published.page(page).per(count)
    end
  end
end
