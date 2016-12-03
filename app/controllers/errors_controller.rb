class ErrorsController < ApplicationController

  def file_not_found
    expires_in 24.hours, public: true
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
