class DenaliSchema < GraphQL::Schema
  max_depth 3
  query(Types::QueryType)
end
