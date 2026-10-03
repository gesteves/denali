require 'rails_helper'

RSpec.describe RetagEntriesJob, type: :worker do
  let(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }
  let(:camera) { create(:camera, make: 'Fujifilm', display_name: 'Fujifilm X100V') }
  let!(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

  before do
    entry.photos.first.update!(camera: camera)
    entry.update_tags
  end

  it "replaces the old name in its entries' equipment tags" do
    camera.update_column(:display_name, 'Fujifilm X100VI')

    described_class.new.perform('Camera', camera.id)

    expect(entry.reload.equipment_list).to include('Fujifilm X100VI')
    expect(entry.equipment_list).not_to include('Fujifilm X100V')
  end

  it 'ignores classes it was not written for' do
    expect { described_class.new.perform('User', user.id) }.not_to raise_error
  end

  it 'does nothing for a record that is gone' do
    expect { described_class.new.perform('Camera', 0) }.not_to raise_error
  end
end
