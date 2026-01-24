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
end
