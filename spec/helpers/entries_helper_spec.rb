require 'rails_helper'

RSpec.describe EntriesHelper, type: :helper do
  let(:photo) { create(:photo, :with_exif) }

  describe '#feed_camera_details' do
    it 'returns nil without a camera' do
      expect(helper.feed_camera_details(photo)).to be_nil
    end

    it 'describes the camera, lens and film' do
      photo.update!(camera: create(:camera, display_name: 'Canon EOS 5D'), lens: create(:lens), film: create(:film))
      html = helper.feed_camera_details(photo)

      expect(html).to start_with('📷 Photographed with a Canon EOS 5D + ')
      expect(html).to include(" on #{photo.film.display_name}")
      expect(html).to end_with('<br>')
    end

    it 'escapes the equipment names' do
      photo.update!(camera: create(:camera, display_name: 'Evil <script>alert(1)</script>'))
      html = helper.feed_camera_details(photo)

      expect(html).not_to include('<script>')
      expect(html).to include('&lt;script&gt;')
    end
  end

  describe '#feed_exif' do
    it 'returns nil for film photos' do
      photo.update!(film: create(:film))
      expect(helper.feed_exif(photo)).to be_nil
    end

    it 'italicizes the f in the aperture' do
      html = helper.feed_exif(photo)

      expect(html).to eq('🎞️ 50 mm focal length – 1/250″ at <i>f</i>/2.8 – ISO 400<br>')
      expect(html).to be_html_safe
    end
  end

  describe '#feed_location' do
    it 'returns nil without a location or territories' do
      expect(helper.feed_location(photo)).to be_nil
    end

    it 'escapes territory names' do
      territory = create(:territory, name: '<img src=x onerror=alert(1)>')
      create(:photo_territory, photo: photo, territory: territory)
      photo.reload

      rendered = ERB::Util.html_escape(helper.feed_location(photo))

      expect(rendered).not_to include('<img')
      expect(rendered).to include('&lt;img src=x onerror=alert(1)&gt; land')
    end
  end
end
