require 'rails_helper'

RSpec.describe Park, type: :model do
  describe 'associations' do
    it { should have_many(:photos) }
  end

  describe 'validations' do
    subject { create(:park) }

    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug) }
    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code) }
    it { should validate_presence_of(:full_name) }
  end

  describe 'factory' do
    it 'creates a valid park' do
      park = create(:park)
      expect(park).to be_valid
    end
  end

  describe '.designations' do
    it 'returns unique designations from all parks' do
      # Clean up any existing parks first
      Park.destroy_all

      create(:park, designation: 'National Park')
      create(:park, designation: 'National Monument')
      create(:park, designation: 'National Park')

      expect(Park.designations).to contain_exactly('National Park', 'National Monument')
    end
  end

  describe '.names' do
    it 'returns unique display names from all parks' do
      create(:park, display_name: 'Yellowstone')
      create(:park, display_name: 'Yosemite')

      expect(Park.names).to contain_exactly('Yellowstone', 'Yosemite')
    end
  end

  describe '#entries_count' do
    let(:user) { create(:user) }
    let(:blog) { create(:blog) }
    let(:park) { create(:park) }

    it 'returns the count of entries with photos in this park' do
      entry1 = create(:entry, blog: blog, user: user)
      entry2 = create(:entry, blog: blog, user: user)
      create(:photo, entry: entry1, park: park)
      create(:photo, entry: entry2, park: park)
      create(:photo, entry: entry2, park: park) # Same entry

      expect(park.entries_count).to eq(2)
    end
  end
end
