require 'rails_helper'

RSpec.describe PhotoExifWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
  end

  describe '#perform' do
    let(:exif_data) do
      double(
        'EXIFR::JPEG',
        present?: true,
        exif?: true,
        make: 'Canon',
        model: 'EOS R5',
        lens_make: 'Canon',
        lens_model: 'RF 50mm F1.2',
        iso_speed_ratings: 400,
        date_time: Time.current,
        exposure_time: Rational(1, 250),
        f_number: Rational(28, 10),
        focal_length: Rational(50, 1),
        gps: nil,
        user_comment: nil,
        image_description: nil
      )
    end

    it 'extracts EXIF data and saves to photo' do
      allow(URI).to receive(:open).and_return(double(path: '/tmp/photo.jpg'))
      allow(EXIFR::JPEG).to receive(:new).and_return(exif_data)

      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.camera).not_to be_nil
      expect(photo.camera.display_name).to eq('Canon EOS R5')
      expect(photo.lens).not_to be_nil
      expect(photo.iso).to eq(400)
    end

    it 'extracts GPS coordinates when present' do
      gps = double('GPS', latitude: 40.7128, longitude: -74.0060)
      allow(exif_data).to receive(:gps).and_return(gps)
      allow(URI).to receive(:open).and_return(double(path: '/tmp/photo.jpg'))
      allow(EXIFR::JPEG).to receive(:new).and_return(exif_data)

      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.latitude).to eq(40.7128)
      expect(photo.longitude).to eq(-74.0060)
    end

    it 'extracts film info from user comment' do
      allow(exif_data).to receive(:user_comment).and_return("Film Make: Kodak\nFilm Type: Portra 400")
      allow(URI).to receive(:open).and_return(double(path: '/tmp/photo.jpg'))
      allow(EXIFR::JPEG).to receive(:new).and_return(exif_data)

      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.film).not_to be_nil
    end

    it 'enqueues AltTextWorker when no alt text present' do
      allow(exif_data).to receive(:image_description).and_return(nil)
      allow(URI).to receive(:open).and_return(double(path: '/tmp/photo.jpg'))
      allow(EXIFR::JPEG).to receive(:new).and_return(exif_data)
      photo.update!(alt_text: nil)

      described_class.new.perform(photo.id)

      expect(AltTextWorker.jobs.size).to eq(1)
    end

    it 'uses image_description for alt_text when present' do
      allow(exif_data).to receive(:image_description).and_return('A beautiful sunset')
      allow(URI).to receive(:open).and_return(double(path: '/tmp/photo.jpg'))
      allow(EXIFR::JPEG).to receive(:new).and_return(exif_data)
      photo.update!(alt_text: nil)

      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.alt_text).to eq('A beautiful sunset')
      expect(AltTextWorker.jobs.size).to eq(0)
    end

    it 'enqueues NationalParkWorker when park code present' do
      allow(exif_data).to receive(:user_comment).and_return("Park: yose")
      allow(URI).to receive(:open).and_return(double(path: '/tmp/photo.jpg'))
      allow(EXIFR::JPEG).to receive(:new).and_return(exif_data)

      described_class.new.perform(photo.id)

      expect(NationalParkWorker.jobs.size).to eq(1)
    end
  end
end
