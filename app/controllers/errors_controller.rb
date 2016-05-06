class ErrorsController < ApplicationController
  before_action :check_if_user_has_visited
  
  def file_not_found
    @errors = [{ status: 404, message: 'Page not found' }]
    render 'error', status: @errors.first[:status]
  end

  def unprocessable
    @errors = [{ status: 422, message: 'Unprocessable entity' }]
    render 'error', status: @errors.first[:status]
  end

  def internal_server_error
    @status = 500
    @message = 'Internal server error'
    @errors = [{ status: 500, message: 'Internal server error' }]
    render 'error', status: @errors.first[:status]
  end

end
