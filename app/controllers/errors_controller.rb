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
    # Cache 404s briefly, so vulnerability scanners hammering /wp-login.php and
    # friends are absorbed at the edge. 422s and 500s are transient by nature and
    # must never be served twice.
    @errors.first[:status] == 404 ? set_max_age(seconds: 1.minute.to_i) : no_store

    respond_to do |format|
      format.html {
        @page_title = "#{@errors.first[:message]} – #{@photoblog.name }"
        render 'error', status: @errors.first[:status]
      }
      format.json { render 'error', status: @errors.first[:status] }
      format.all { render plain: @errors.first[:message], status: @errors.first[:status] }
    end
  end

end
