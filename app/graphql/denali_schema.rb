class DenaliSchema < GraphQL::Schema
  max_depth 18
  query(Types::QueryType)
end
