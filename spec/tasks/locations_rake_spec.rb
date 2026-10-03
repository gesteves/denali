require 'rails_helper'

RSpec.describe 'locations rake tasks', type: :task do
  describe 'locations:clear:park_locations' do
    let(:blog) { create(:blog) }
    let(:entry) { create(:entry, :published, blog: blog, user: create(:user)) }
    let!(:in_park) { create(:photo, entry: entry, park: create(:park), location: 'Somewhere') }
    let!(:not_in_park) { create(:photo, entry: entry, location: 'Elsewhere') }

    it 'clears the location of photos that have a park, and only those' do
      run_task('locations:clear:park_locations')

      expect(in_park.reload.location).to be_nil
      expect(not_in_park.reload.location).to eq('Elsewhere')
    end

    it 'changes nothing on a dry run' do
      run_task('locations:clear:park_locations', 'DRY_RUN' => 'true')
      expect(in_park.reload.location).to eq('Somewhere')
    end
  end
end
