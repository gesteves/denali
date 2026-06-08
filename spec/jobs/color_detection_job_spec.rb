require 'rails_helper'

RSpec.describe ColorDetectionJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
  end

  describe '#perform' do
    before do
      # Stub photo.url to return a valid path for MiniMagick
      allow_any_instance_of(Photo).to receive(:url).and_return('http://example.com/photo.jpg')
    end

    it 'detects color photo and sets flags correctly' do
      mock_image = double('MiniMagick::Image', path: '/tmp/photo.jpg')
      mock_grayscale = double('MiniMagick::Image', path: '/tmp/photo_gray.jpg')
      allow(MiniMagick::Image).to receive(:open).and_return(mock_image, mock_grayscale)

      # Use double since MiniMagick::Tool uses method_missing DSL
      mock_compare = double('MiniMagick::Tool')
      allow(MiniMagick::Tool).to receive(:new).with("compare").and_return(mock_compare)
      allow(mock_compare).to receive(:metric).and_return(mock_compare)
      allow(mock_compare).to receive(:<<).and_return(mock_compare)
      # High mean error = color photo (format: "count mean_error" where mean_error > threshold)
      allow(mock_compare).to receive(:call).and_return(['0 10.5', nil])

      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.color).to be true
      expect(photo.black_and_white).to be false
    end

    it 'detects black and white photo and sets flags correctly' do
      mock_image = double('MiniMagick::Image', path: '/tmp/photo.jpg')
      mock_grayscale = double('MiniMagick::Image', path: '/tmp/photo_gray.jpg')
      allow(MiniMagick::Image).to receive(:open).and_return(mock_image, mock_grayscale)

      mock_compare = double('MiniMagick::Tool')
      allow(MiniMagick::Tool).to receive(:new).with("compare").and_return(mock_compare)
      allow(mock_compare).to receive(:metric).and_return(mock_compare)
      allow(mock_compare).to receive(:<<).and_return(mock_compare)
      # Low mean error = black and white photo (format: "count mean_error" where mean_error <= threshold)
      allow(mock_compare).to receive(:call).and_return(['0 0.5', nil])

      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.color).to be false
      expect(photo.black_and_white).to be true
    end

    it 'defaults to color when error occurs' do
      allow(MiniMagick::Image).to receive(:open).and_raise(StandardError.new('Test error'))

      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.color).to be true
      expect(photo.black_and_white).to be false
    end

    it 'ensures the photo is analyzed before processing' do
      allow(MiniMagick::Image).to receive(:open).and_raise(StandardError.new('Test error'))

      expect_any_instance_of(Photo).to receive(:ensure_analyzed!)

      described_class.new.perform(photo.id)
    end
  end
end
