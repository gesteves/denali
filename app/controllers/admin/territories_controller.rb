class Admin::TerritoriesController < AdminController
  def index
    @territories = Territory.left_joins(photos: :entry)
                            .where(entries: { status: 'published' })
                            .group(:id)
                            .select('territories.*, COUNT(DISTINCT entries.id) AS entries_count')
                            .order('entries_count DESC')
    @page_title = 'Territories'
    respond_to do |format|
      format.html
    end
  end
end
