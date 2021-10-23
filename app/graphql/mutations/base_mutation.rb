module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Types::BaseInputObject
    object_class Types::BaseObject

    def ready?(**args)
      raise GraphQL::ExecutionError, "You don’t have permission to do this." unless context[:is_authorized]
      true
    end
  end
end
