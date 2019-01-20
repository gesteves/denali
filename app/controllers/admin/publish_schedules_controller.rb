class Admin::PublishSchedulesController < AdminController

  def index
    @schedules = @photoblog.publish_schedules
    @page_title = 'Publish Schedules'
    @queued_entries = @photoblog.entries.queued.count
    respond_to do |format|
      format.html
      format.js
    end
  end

  def new

  end

  def create

  end

  def destroy
    schedule = PublishSchedule.find(params[:id])
    schedule.destroy
    respond_to do |format|
      format.html { redirect_to admin_publish_schedules_path }
      format.json {
        response = {
          status: 'danger',
          message: "The publish time has been deleted!"
        }
        render json: response
      }
    end
  end
end
