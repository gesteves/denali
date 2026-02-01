require 'rails_helper'

RSpec.describe Film, type: :model do
  describe 'associations' do
    it { should have_many(:photos) }
  end

  describe 'validations' do
    subject { create(:film) }

    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug) }
    it { should validate_presence_of(:make) }
    it { should validate_presence_of(:model) }
    it { should validate_presence_of(:display_name) }
  end

  describe 'factory' do
    it 'creates a valid film' do
      film = create(:film)
      expect(film).to be_valid
    end
  end

  describe 'callbacks' do
    describe '#update_entry_tags' do
      let(:blog) { Blog.first || create(:blog) }
      let(:user) { create(:user) }
      let!(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
      let!(:film) { create(:film) }

      before do
        entry.photos.each { |p| attach_image_to_photo(p) }
        entry.photos.first.update!(film: film)
      end

      it 'triggers callback when display_name changes' do
        expect(film).to receive(:update_entry_tags).and_call_original
        film.update!(display_name: 'New Film Name')
      end

      it 'does not trigger callback when other attributes change' do
        expect(film).not_to receive(:update_entry_tags)
        film.update!(make: 'Updated Make')
      end
    end
  end
end
