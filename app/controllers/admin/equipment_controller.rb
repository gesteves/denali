class Admin::EquipmentController < AdminController
  def index
    @cameras = Camera.order('make asc, model asc')
    @lenses = Lens.order('make asc, model asc')
    @films = Film.order('make asc, model asc')
    @page_title = 'Equipment'
  end
end
