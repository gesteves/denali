require 'rails_helper'

RSpec.describe Lens, type: :model do
  describe 'associations' do
    it { should have_many(:photos) }
  end

  describe 'validations' do
    subject { create(:lens) }

    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug) }
    it { should validate_presence_of(:make) }
    it { should validate_presence_of(:model) }
    it { should validate_presence_of(:display_name) }
  end

  describe 'factory' do
    it 'creates a valid lens' do
      lens = create(:lens)
      expect(lens).to be_valid
    end
  end

  describe 'callbacks' do
    describe '#update_entry_tags' do
      let(:blog) { Blog.first || create(:blog) }
      let(:user) { create(:user) }
      let!(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
      let!(:lens) { create(:lens) }

      before do
        entry.photos.each { |p| attach_image_to_photo(p) }
        entry.photos.first.update!(lens: lens)
      end

      # Retagging saves every entry, so it runs in a job after the rename commits.
      it 'retags its entries in a job when display_name changes' do
        lens.update!(display_name: 'New Lens Name')
        expect(RetagEntriesJob.jobs.map { |job| job['args'] }).to eq([['Lens', lens.id]])
      end

      it 'does not retag when other attributes change' do
        lens.update!(make: 'Updated Make')
        expect(RetagEntriesJob.jobs).to be_empty
      end
    end
  end
end
