class DenaliSchema < GraphQL::Schema
  max_depth 5
  query(Types::QueryType)
end
