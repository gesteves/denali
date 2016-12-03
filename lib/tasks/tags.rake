namespace :tags do
  namespace :update do
    task :objects => [:environment] do
      Entry.find_each do |e|
        ImageAnalysisJob.perform_later(e)
      end
    end
  end
end
