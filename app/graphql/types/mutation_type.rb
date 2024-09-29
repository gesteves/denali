class Types::MutationType < Types::BaseObject
    field :expire_blog_cache, mutation: Mutations::ExpireBlogCache
    field :share_on_bluesky, mutation: Mutations::ShareOnBluesky
end
