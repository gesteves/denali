class Admin::EquipmentController < AdminController
  def index
    if stale?(@photoblog)
      @cameras = Camera.order('make asc, model asc')
      @lenses = Lens.order('make asc, model asc')
      @films = Film.order('make asc, model asc')
      @page_title = 'Equipment'
      respond_to do |format|
        format.html
      end
    end
  end
end
