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
end
