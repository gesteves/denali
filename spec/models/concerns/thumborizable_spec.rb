require 'rails_helper'

RSpec.describe Thumborizable, type: :model do
  let(:user) { create(:user) }
  let(:blog) { create(:blog) }
  let(:entry) { create(:entry, blog: blog, user: user) }
  let(:photo) { create(:photo, entry: entry) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DOMAIN').and_return('www.example.com')
  end

  describe '#thumbor_url' do
    it 'returns nil for a blank image' do
      expect(photo.thumbor_url(nil)).to be_nil
      expect(photo.thumbor_url('')).to be_nil
    end

    # The bucket is resolved by the worker, so its hostname never appears here.
    it 'addresses a blob by key, without exposing the bucket' do
      expect(photo.thumbor_url('abc123', width: 500)).to eq('https://www.example.com/images/width=500/abc123')
    end

    it 'serves the original when no options apply' do
      expect(photo.thumbor_url('abc123')).to eq('https://www.example.com/images/abc123')
    end

    it 'includes width and height' do
      expect(photo.thumbor_url('abc123', width: 500, height: 300)).to eq('https://www.example.com/images/width=500,height=300/abc123')
    end

    it 'translates a crop rect into a trim option and omits height' do
      allow(photo).to receive(:width).and_return(1000)
      allow(photo).to receive(:height).and_return(1500)

      url = photo.thumbor_url('abc123', crop: [100, 200, 900, 1300], width: 500, height: 750)
      expect(url).to eq('https://www.example.com/images/trim=200;100;200;100,width=500/abc123')
    end

    it 'translates fit_in and fill into fit=pad and background' do
      url = photo.thumbor_url('abc123', width: 500, height: 300, fit_in: true, fill: 'fff')
      expect(url).to eq('https://www.example.com/images/width=500,height=300,fit=pad,background=%23fff/abc123')
    end

    it 'translates grayscale into saturation=0' do
      expect(photo.thumbor_url('abc123', width: 300, grayscale: true)).to eq('https://www.example.com/images/width=300,saturation=0/abc123')
    end

    it 'includes quality' do
      expect(photo.thumbor_url('abc123', width: 300, quality: 80)).to eq('https://www.example.com/images/width=300,quality=80/abc123')
    end

    ['auto', 'jpeg', 'webp', 'avif'].each do |format|
      it "includes format=#{format}" do
        expect(photo.thumbor_url('abc123', width: 300, format: format)).to include("format=#{format}")
      end
    end

    it 'omits the format option for png, preserving the source format' do
      expect(photo.thumbor_url('abc123', width: 16, format: 'png')).to eq('https://www.example.com/images/width=16/abc123')
    end

    it 'omits unsupported formats' do
      expect(photo.thumbor_url('abc123', width: 300, format: 'bmp')).not_to include('format=')
    end
  end

  describe 'integration with Photo' do
    before do
      allow(photo).to receive(:width).and_return(3000)
      allow(photo).to receive(:height).and_return(2000)
      allow(photo).to receive(:image).and_return(double('image', key: 'abc123'))
    end

    it 'translates a focal-point aspect-ratio crop into a trim option' do
      photo.focal_x = 0.5
      photo.focal_y = 0.5

      # 1:1 crop of a 3000x2000 photo centered at (0.5, 0.5) -> rect [500, 0, 2500, 2000]
      url = photo.url(aspect_ratio: '1:1', width: 500)
      expect(url).to eq('https://www.example.com/images/trim=0;500;0;500,width=500/abc123')
    end

    it 'translates a stored Crop record into a trim option' do
      create(:crop, photo: photo, aspect_ratio: '16:9', x: 0.1, y: 0.1, width: 0.8, height: 0.8)
      photo.reload
      allow(photo).to receive(:width).and_return(3000)
      allow(photo).to receive(:height).and_return(2000)
      allow(photo).to receive(:image).and_return(double('image', key: 'abc123'))

      # rect: left=300, top=200, right=2700, bottom=1800 -> trim=200;300;200;300
      url = photo.url(aspect_ratio: '16:9', width: 500)
      expect(url).to eq('https://www.example.com/images/trim=200;300;200;300,width=500/abc123')
    end

    # Served by the worker's /ig/ route rather than a plain transform, because
    # matting on all four sides needs two chained transforms.
    it 'frames a horizontal photo onto a square, inset on the axis it would meet' do
      expect(photo.instagram_url).to eq('https://www.example.com/ig/1340x1440/1440x1440/abc123')
    end

    it 'frames a vertical photo onto 4:5, inset on the axis it would meet' do
      allow(photo).to receive(:width).and_return(2000)
      allow(photo).to receive(:height).and_return(3000)

      expect(photo.instagram_url).to eq('https://www.example.com/ig/1440x1700/1440x1800/abc123')
    end

    # Cloudflare cannot fetch a transform URL as the source of another
    # transform; it fails with "ERROR 9404: Could not fetch the image".
    it 'never nests one transform inside another' do
      urls = [
        photo.instagram_url,
        photo.instagram_story_url,
        photo.facebook_card_url,
        photo.mastodon_url,
        photo.threads_url,
        photo.bluesky_url,
        photo.sitemap_url,
        photo.claude_url,
        photo.iphone_wallpaper_url,
        photo.url(width: 800)
      ]

      urls.each do |url|
        expect(url.scan('/images/').length).to be <= 1, "nested transform: #{url}"
      end
    end
  end
end
