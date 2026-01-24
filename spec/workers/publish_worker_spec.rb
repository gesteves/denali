require 'rails_helper'

RSpec.describe PublishWorker, type: :worker do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }

  before do
    # Clear any existing entries to ensure clean state
    blog.entries.destroy_all
  end

  describe '#perform' do
    context 'when no entry was published in last 10 minutes' do
      let!(:old_entry) { create(:entry, :published, blog: blog, user: user, published_at: 15.minutes.ago) }

      it 'calls publish_queued_entry! on the blog' do
        expect(blog).to receive(:publish_queued_entry!)
        allow(Blog).to receive(:first).and_return(blog)
        described_class.new.perform
      end
    end

    context 'when an entry was published in last 10 minutes' do
      let!(:recent_entry) { create(:entry, :published, blog: blog, user: user, published_at: 5.minutes.ago) }

      it 'does not call publish_queued_entry!' do
        expect(blog).not_to receive(:publish_queued_entry!)
        allow(Blog).to receive(:first).and_return(blog)
        described_class.new.perform
      end
    end
  end
end
