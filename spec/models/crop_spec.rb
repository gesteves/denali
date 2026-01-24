require 'rails_helper'

RSpec.describe Crop, type: :model do
  let(:user) { create(:user) }
  let(:blog) { create(:blog) }
  let(:entry) { create(:entry, blog: blog, user: user) }
  let(:photo) { create(:photo, entry: entry) }

  describe 'associations' do
    it { should belong_to(:photo).optional }
  end

  describe 'validations' do
    subject { create(:crop, photo: photo) }

    it { should validate_presence_of(:x) }
    it { should validate_presence_of(:y) }
    it { should validate_presence_of(:width) }
    it { should validate_presence_of(:height) }
    it { should validate_presence_of(:aspect_ratio) }

    it { should validate_numericality_of(:x).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(1) }
    it { should validate_numericality_of(:y).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(1) }
    it { should validate_numericality_of(:width).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(1) }
    it { should validate_numericality_of(:height).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(1) }

    it 'validates uniqueness of aspect_ratio scoped to photo_id' do
      create(:crop, photo: photo, aspect_ratio: '1:1')
      duplicate = build(:crop, photo: photo, aspect_ratio: '1:1')
      expect(duplicate).not_to be_valid
    end
  end

  describe 'factory' do
    it 'creates a valid crop' do
      crop = create(:crop, photo: photo)
      expect(crop).to be_valid
    end
  end

  describe '#to_rect' do
    it 'converts relative coordinates to absolute pixels' do
      allow(photo).to receive(:width).and_return(1000)
      allow(photo).to receive(:height).and_return(800)

      crop = create(:crop, photo: photo, x: 0.1, y: 0.2, width: 0.5, height: 0.6)

      rect = crop.to_rect
      expect(rect[0]).to eq(100)  # left
      expect(rect[1]).to eq(160)  # top
      expect(rect[2]).to eq(600)  # right (100 + 500)
      expect(rect[3]).to eq(640)  # bottom (160 + 480)
    end
  end
end
