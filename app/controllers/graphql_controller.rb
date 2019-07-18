class GraphqlController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_cors_headers
  
  def execute
    variables = ensure_hash(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      # Query context goes here, for example:
      # current_user: current_user,
    }
    result = DenaliSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    set_cors_headers
    render json: result
  rescue => e
    raise e unless Rails.env.development?
    handle_error_in_development e
  end
  
  def options
    render plain: 'OK', status: 200
  end

  private

  # Handle form data, JSON body, or a blank value
  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      if ambiguous_param.present?
        ensure_hash(JSON.parse(ambiguous_param))
      else
        {}
      end
    when Hash, ActionController::Parameters
      ambiguous_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { error: { message: e.message, backtrace: e.backtrace }, data: {} }, status: 500
  end
  
  def set_cors_headers
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'x-apollo-tracing, content-type'
    response.headers['Access-Control-Allow-Methods'] = 'POST'
    response.headers['Access-Control-Max-Age'] = 86400
  end
end
