require 'rails_helper'

RSpec.describe BlurhashJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
  end

  describe '#perform' do
    it 'generates and saves blurhash for photo' do
      mock_image = instance_double(MiniMagick::Image, width: 100, height: 100)
      allow(mock_image).to receive(:get_pixels).and_return(Array.new(100) { Array.new(100) { [128, 128, 128] } })
      allow(MiniMagick::Image).to receive(:open).and_return(mock_image)
      allow(Blurhash).to receive(:encode).and_return('LKO2?U%2Tw=w]~RBVZRi};RPxuwH')

      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.blurhash).to eq('LKO2?U%2Tw=w]~RBVZRi};RPxuwH')
    end

    it 'does not save when blurhash is blank' do
      mock_image = instance_double(MiniMagick::Image, width: 100, height: 100)
      allow(mock_image).to receive(:get_pixels).and_return([])
      allow(MiniMagick::Image).to receive(:open).and_return(mock_image)
      allow(Blurhash).to receive(:encode).and_return(nil)

      original_blurhash = photo.blurhash
      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.blurhash).to eq(original_blurhash)
    end

    it 'ensures the photo is analyzed before processing' do
      mock_image = instance_double(MiniMagick::Image, width: 100, height: 100)
      allow(mock_image).to receive(:get_pixels).and_return([])
      allow(MiniMagick::Image).to receive(:open).and_return(mock_image)
      allow(Blurhash).to receive(:encode).and_return(nil)

      expect_any_instance_of(Photo).to receive(:ensure_analyzed!)

      described_class.new.perform(photo.id)
    end

    it 'raises UnprocessedPhotoError when dimensions cannot be determined' do
      allow_any_instance_of(Photo).to receive(:ensure_analyzed!)
      allow_any_instance_of(Photo).to receive(:has_dimensions?).and_return(false)

      expect { described_class.new.perform(photo.id) }.to raise_error(UnprocessedPhotoError)
    end
  end
end
