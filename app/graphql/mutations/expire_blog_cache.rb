module Mutations
  class ExpireBlogCache < BaseMutation
    field :blog, Types::BlogType, null: false
    field :errors, [String], null: false

    def resolve
      blog = Blog.first
      blog.invalidate
      {
        blog: blog,
        errors: []
      }
    end
  end
end
