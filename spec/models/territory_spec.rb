require 'rails_helper'

RSpec.describe Territory, type: :model do
  describe 'associations' do
    it { should have_many(:photo_territories).dependent(:destroy) }
    it { should have_many(:photos).through(:photo_territories) }
  end

  describe 'validations' do
    subject { create(:territory) }

    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug) }
    it { should validate_presence_of(:name) }
  end

  describe 'factory' do
    it 'creates a valid territory' do
      territory = create(:territory)
      expect(territory).to be_valid
    end
  end

  describe 'photo association' do
    let(:blog) { Blog.first || create(:blog) }
    let(:user) { create(:user) }
    let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
    let(:territory) { create(:territory) }
    let(:photo) { entry.photos.first }

    before do
      attach_image_to_photo(photo)
    end

    it 'can be associated with photos' do
      photo.territories << territory
      expect(photo.territories).to include(territory)
      expect(territory.photos).to include(photo)
    end

    it 'destroys photo_territories when territory is destroyed' do
      photo.territories << territory
      expect {
        territory.destroy
      }.to change(PhotoTerritory, :count).by(-1)
    end

    it 'does not destroy photos when territory is destroyed' do
      photo.territories << territory
      expect {
        territory.destroy
      }.not_to change(Photo, :count)
    end
  end
end
