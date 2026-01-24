require 'rails_helper'

RSpec.describe Camera, type: :model do
  describe 'associations' do
    it { should have_many(:photos) }
  end

  describe 'validations' do
    subject { create(:camera) }

    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug) }
    it { should validate_presence_of(:make) }
    it { should validate_presence_of(:model) }
    it { should validate_presence_of(:display_name) }
  end

  describe 'factory' do
    it 'creates a valid camera' do
      camera = create(:camera)
      expect(camera).to be_valid
    end

    it 'creates a phone camera with phone trait' do
      camera = create(:camera, :phone)
      expect(camera).to be_is_phone
    end
  end

  describe '#article' do
    it 'returns "a" for names starting with consonants' do
      camera = create(:camera, display_name: 'Canon EOS 5D')
      expect(camera.article).to eq('a')
    end

    it 'returns "an" for names starting with vowels' do
      camera = create(:camera, display_name: 'Olympus OM-D')
      expect(camera.article).to eq('an')
    end
  end
end
