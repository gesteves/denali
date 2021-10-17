class Admin::LocationsController < AdminController
  def index
    @parks = Park.order('full_name asc')
    @page_title = 'Locations'
    respond_to do |format|
      format.html
    end
  end
end
