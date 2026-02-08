require 'rails_helper'

RSpec.describe PhotoAnalyzeJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
  end

  describe '#perform' do
    it 'calls analyze on the photo image' do
      # Stub the analyze method on the blob, which is what gets called
      expect_any_instance_of(ActiveStorage::Blob).to receive(:analyze)
      described_class.new.perform(photo.id)
    end
  end
end
