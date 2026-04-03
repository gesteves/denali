require 'rails_helper'

RSpec.describe Photo, type: :model do
  let(:user) { create(:user) }
  let(:blog) { create(:blog) }
  let(:entry) { create(:entry, blog: blog, user: user) }

  describe 'associations' do
    it { should belong_to(:entry).optional }
    it { should belong_to(:camera).optional }
    it { should belong_to(:lens).optional }
    it { should belong_to(:film).optional }
    it { should belong_to(:park).optional }
    it { should have_many(:crops).dependent(:destroy) }
    it { should have_many(:photo_territories).dependent(:destroy) }
    it { should have_many(:territories).through(:photo_territories) }
  end

  describe 'touching entry' do
    it 'updating a photo should update entry' do
      photo = create(:photo, entry: entry)
      original_updated_at = entry.updated_at

      sleep(0.01) # Ensure time passes
      photo.update!(alt_text: 'Foo')
      entry.reload

      expect(entry.updated_at).not_to eq(original_updated_at)
    end
  end

  describe 'territory_list' do
    let(:territory1) { create(:territory, name: 'Shoshone-Bannock') }
    let(:territory2) { create(:territory, name: 'Eastern Shoshone') }
    let(:territory3) { create(:territory, name: 'Cheyenne') }

    it 'returns nil when no territories' do
      photo = create(:photo, entry: entry)
      expect(photo.territories).to be_empty
      expect(photo.territory_list).to be_nil
    end

    it 'formats single territory correctly' do
      photo = create(:photo, entry: entry)
      create(:photo_territory, photo: photo, territory: territory1)
      photo.reload

      expect(photo.territory_list).to eq('Shoshone-Bannock')
    end

    it 'formats two territories correctly' do
      photo = create(:photo, entry: entry)
      create(:photo_territory, photo: photo, territory: territory1)
      create(:photo_territory, photo: photo, territory: territory2)
      photo.reload

      expect(photo.territory_list).to eq('Shoshone-Bannock and Eastern Shoshone')
    end

    it 'formats three territories correctly' do
      photo = create(:photo, entry: entry)
      create(:photo_territory, photo: photo, territory: territory1)
      create(:photo_territory, photo: photo, territory: territory2)
      create(:photo_territory, photo: photo, territory: territory3)
      photo.reload

      expect(photo.territory_list).to eq('Shoshone-Bannock, Eastern Shoshone, and Cheyenne')
    end
  end

  describe 'mastodon_focal_point' do
    it 'returns empty array when focal points are nil' do
      photo = create(:photo, entry: entry, focal_x: nil, focal_y: nil)
      expect(photo.mastodon_focal_point).to eq([])
    end

    it 'transforms top-left (0, 0) to (-1, 1)' do
      photo = create(:photo, entry: entry, focal_x: 0, focal_y: 0)
      expect(photo.mastodon_focal_point).to eq([-1.0, 1.0])
    end

    it 'transforms center (0.5, 0.5) to (0, 0)' do
      photo = create(:photo, entry: entry, focal_x: 0.5, focal_y: 0.5)
      expect(photo.mastodon_focal_point).to eq([0, 0])
    end

    it 'transforms bottom-right (1, 1) to (1, -1)' do
      photo = create(:photo, entry: entry, focal_x: 1.0, focal_y: 1.0)
      expect(photo.mastodon_focal_point).to eq([1.0, -1.0])
    end
  end

  describe 'formatted methods' do
    describe '#formatted_aperture' do
      it 'returns empty string when f_number is blank' do
        photo = create(:photo, entry: entry, f_number: nil)
        expect(photo.formatted_aperture).to eq('')
      end

      it 'formats aperture correctly' do
        photo = create(:photo, entry: entry, f_number: 2.8)
        expect(photo.formatted_aperture).to eq('f/2.8')
      end
    end

    describe '#formatted_exposure' do
      it 'returns empty string when exposure is blank' do
        photo = create(:photo, entry: entry, exposure: nil)
        expect(photo.formatted_exposure).to eq('')
      end

      it 'formats fractional exposure correctly' do
        photo = create(:photo, entry: entry, exposure: '1/250')
        expect(photo.formatted_exposure).to eq('1/250″')
      end
    end

    describe '#focal_length_with_unit' do
      it 'returns empty string when focal_length is blank' do
        photo = create(:photo, entry: entry, focal_length: nil)
        expect(photo.focal_length_with_unit).to eq('')
      end

      it 'formats focal length with unit' do
        photo = create(:photo, entry: entry, focal_length: 50)
        expect(photo.focal_length_with_unit).to eq('50 mm')
      end
    end

    describe '#formatted_exif' do
      it 'combines all exif data' do
        photo = create(:photo, :with_exif, entry: entry)
        expect(photo.formatted_exif).to include('50 mm')
        expect(photo.formatted_exif).to include('f/2.8')
        expect(photo.formatted_exif).to include('ISO 400')
      end
    end
  end

  describe 'dimension helpers' do
    describe '#has_dimensions?' do
      it 'returns false when width or height is missing' do
        photo = create(:photo, entry: entry)
        allow(photo).to receive(:width).and_return(nil)
        allow(photo).to receive(:height).and_return(nil)
        expect(photo.has_dimensions?).to be false
      end
    end

    describe '#is_vertical?' do
      it 'returns true when height > width' do
        photo = create(:photo, entry: entry)
        allow(photo).to receive(:width).and_return(1000)
        allow(photo).to receive(:height).and_return(1500)
        allow(photo).to receive(:has_dimensions?).and_return(true)
        expect(photo.is_vertical?).to be true
      end
    end

    describe '#is_horizontal?' do
      it 'returns true when width > height' do
        photo = create(:photo, entry: entry)
        allow(photo).to receive(:width).and_return(1500)
        allow(photo).to receive(:height).and_return(1000)
        allow(photo).to receive(:has_dimensions?).and_return(true)
        expect(photo.is_horizontal?).to be true
      end
    end

    describe '#is_square?' do
      it 'returns true when width == height' do
        photo = create(:photo, entry: entry)
        allow(photo).to receive(:width).and_return(1000)
        allow(photo).to receive(:height).and_return(1000)
        allow(photo).to receive(:has_dimensions?).and_return(true)
        expect(photo.is_square?).to be true
      end
    end
  end

  describe 'location helpers' do
    describe '#has_location?' do
      it 'returns false when coordinates are missing' do
        photo = create(:photo, entry: entry, latitude: nil, longitude: nil)
        expect(photo.has_location?).to be false
      end

      it 'returns true when coordinates are present' do
        photo = create(:photo, :with_location, entry: entry)
        expect(photo.has_location?).to be true
      end
    end
  end

  describe '#warm_cache' do
    it 'makes an HTTP HEAD request to the given URLs' do
      photo = create(:photo, entry: entry)
      url1 = 'https://example.com/image1.jpg'
      url2 = 'https://example.com/image2.jpg'

      expect(HTTParty).to receive(:head).with(url1, timeout: 30)
      expect(HTTParty).to receive(:head).with(url2, timeout: 30)

      photo.warm_cache(url1, url2)
    end

    it 'logs a warning and continues when a request fails' do
      photo = create(:photo, entry: entry)
      url = 'https://example.com/image.jpg'

      allow(HTTParty).to receive(:head).and_raise(Net::ReadTimeout.new('timed out'))

      expect(Rails.logger).to receive(:warn).with(/Failed to warm cache/)
      expect { photo.warm_cache(url) }.not_to raise_error
    end
  end

  describe 'scopes' do
    describe '.needs_alt_text_review' do
      it 'returns photos with blank alt_text' do
        photo1 = create(:photo, entry: entry, alt_text: nil)
        photo2 = create(:photo, entry: entry, alt_text: '')
        photo3 = create(:photo, entry: entry, alt_text: 'Has alt text')

        results = Photo.needs_alt_text_review
        expect(results).to include(photo1, photo2)
        expect(results).not_to include(photo3)
      end

      it 'returns photos with alt_text_needs_review true' do
        photo1 = create(:photo, entry: entry, alt_text: 'Auto text', alt_text_needs_review: true)
        photo2 = create(:photo, entry: entry, alt_text: 'Approved text', alt_text_needs_review: false)

        results = Photo.needs_alt_text_review
        expect(results).to include(photo1)
        expect(results).not_to include(photo2)
      end
    end
  end
end
