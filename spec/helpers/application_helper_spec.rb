require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  let(:user) { create(:user) }
  let(:blog) { create(:blog) }
  let(:entry) { create(:entry, blog: blog, user: user) }
  let(:photo) { create(:photo, entry: entry) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DOMAIN').and_return('www.example.com')
    allow(photo).to receive(:width).and_return(3000)
    allow(photo).to receive(:height).and_return(2000)
    allow(photo).to receive(:image).and_return(double('image', key: 'abc123'))
  end

  describe '#responsive_image_tag' do
    it 'renders a single img rather than a picture element' do
      html = helper.responsive_image_tag(photo: photo, srcset: [300, 600, 1200])

      expect(html).to start_with('<img')
      expect(html).not_to include('<picture')
      expect(html).not_to include('<source')
    end

    it 'builds one srcset covering every width, negotiating format at the edge' do
      html = helper.responsive_image_tag(photo: photo, srcset: [300, 600])

      expect(html).to include('/images/width=300,format=auto/abc123 300w')
      expect(html).to include('/images/width=600,format=auto/abc123 600w')
    end

    it 'uses the requested width for the fallback src' do
      html = helper.responsive_image_tag(photo: photo, srcset: [300, 600, 1200], src: 1200)

      expect(html).to include('src="https://www.example.com/images/width=1200,format=auto/abc123"')
    end

    it 'passes sizes through untouched' do
      html = helper.responsive_image_tag(photo: photo, srcset: [300], sizes: '(min-width: 800px) 400px, 100vw')

      expect(html).to include('sizes="(min-width: 800px) 400px, 100vw"')
    end

    it 'sets the intrinsic dimensions so the image reserves layout space' do
      html = helper.responsive_image_tag(photo: photo, srcset: [300])

      expect(html).to include('width="3000"')
      expect(html).to include('height="2000"')
    end

    it 'lets callers override the defaults' do
      html = helper.responsive_image_tag(photo: photo, srcset: [300], html_options: { loading: 'eager', class: 'foo' })

      expect(html).to include('loading="eager"')
      expect(html).to include('class="foo"')
    end
  end

  describe 'the photo size configuration' do
    # Browsers only honor `sizes: auto` on images with `loading="lazy"`. The
    # entry photo is the LCP element and loads eagerly, so `auto` would be
    # ignored there at best — and when it isn't, it resolves to the 300px
    # default object size and pulls down the smallest candidate.
    it 'does not use sizes=auto for the eagerly loaded entry photo' do
      expect(PHOTOS[:entry][:sizes]).not_to include('auto')
    end

    it 'uses sizes=auto for lazily loaded images' do
      PHOTOS.except(:entry).each do |name, config|
        next unless config.is_a?(Hash) && config[:sizes].present?
        expect(config[:sizes]).to include('auto'), "PHOTOS[:#{name}] is missing sizes=auto"
      end
    end

    it 'gives every media condition a unit' do
      PHOTOS.each do |name, config|
        next unless config.is_a?(Hash) && config[:sizes].present?
        config[:sizes].grep(/min-width:/).each do |size|
          expect(size).to match(/min-width:\s*\d+(px|em|rem)/), "PHOTOS[:#{name}] has a unitless media condition: #{size}"
        end
      end
    end
  end
end
