class Types::MutationType < Types::BaseObject
    field :expire_blog_cache, mutation: Mutations::ExpireBlogCache
end
