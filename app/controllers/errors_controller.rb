class ErrorsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def file_not_found
    @errors = [{ status: 404, message: 'Page not found' }]
    respond
  end

  def unprocessable
    @errors = [{ status: 422, message: 'Unprocessable entity' }]
    respond
  end

  def internal_server_error
    @status = 500
    @message = 'Internal server error'
    @errors = [{ status: 500, message: 'Internal server error' }]
    respond
  end

  private

  def respond
    respond_to do |format|
      format.html { render 'error', status: @errors.first[:status] }
      format.json { render 'error', status: @errors.first[:status] }
      format.all { render plain: @errors.first[:message], status: @errors.first[:status] }
    end
  end

end
