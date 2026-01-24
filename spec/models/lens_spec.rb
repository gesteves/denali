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
end
