class DenaliSchema < GraphQL::Schema
  max_depth 18
  max_complexity 300
  disable_introspection_entry_points unless Rails.env.development?
  query(Types::QueryType)
  mutation(Types::MutationType)
end
