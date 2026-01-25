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

      it 'triggers callback when display_name changes' do
        expect(lens).to receive(:update_entry_tags).and_call_original
        lens.update!(display_name: 'New Lens Name')
      end

      it 'does not trigger callback when other attributes change' do
        expect(lens).not_to receive(:update_entry_tags)
        lens.update!(amazon_url: 'https://amazon.com/lens')
      end
    end
  end
end
