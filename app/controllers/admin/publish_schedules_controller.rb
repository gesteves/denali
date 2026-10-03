class Admin::PublishSchedulesController < AdminController

  def index
    load_index
    @new_schedule = PublishSchedule.new
    respond_to do |format|
      format.html
    end
  end

  def create
    @schedule = PublishSchedule.new(schedule_params)
    @schedule.blog = @photoblog
    respond_to do |format|
      if @schedule.save
        flash[:success] = "Publishing schedule updated!"
        format.html { redirect_to admin_entries_queued_schedule_path }
      else
        flash.now[:warning] = 'The publishing schedule couldn’t be updated…'
        load_index
        @new_schedule = @schedule
        format.html { render :index, status: :unprocessable_content }
      end
    end
  end

  def destroy
    schedule = PublishSchedule.find(params[:id])
    schedule.destroy
    respond_to do |format|
      format.html { redirect_to admin_entries_queued_schedule_path }
    end
  end

  private
  def load_index
    @schedules = @photoblog.publish_schedules
    @page_title = 'Queue schedule'
    @queued_entries = @photoblog.entries.queued.count
  end

  def schedule_params
    params.require(:publish_schedule).permit(:hour)
  end
end
