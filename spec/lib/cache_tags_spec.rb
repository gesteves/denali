require 'rails_helper'

# Controllers attach these and models purge them; both sides have to spell them
# the same way, and Cloudflare only accepts printable ASCII without spaces.
RSpec.describe CacheTags do
  it 'names an entry by its id' do
    expect(described_class.entry(42)).to eq('entry-42')
  end

  it 'only uses characters Cloudflare accepts in a tag' do
    [described_class::ENTRIES, described_class::BLOG, described_class.entry(42)].each do |tag|
      expect(tag).to match(/\A[\x21-\x7E]+\z/)
    end
  end

  describe 'what models purge' do
    let(:blog) { create(:blog) }
    let(:user) { create(:user) }

    it 'purges the lists for a published entry' do
      entry = create(:entry, :published, blog: blog, user: user)
      expect(entry.cache_tags).to eq([described_class.entry(entry.id), described_class::ENTRIES])
    end

    # Every upload edits a draft repeatedly; the lists don't show drafts.
    it 'leaves the lists alone for a draft' do
      entry = create(:entry, :draft, blog: blog, user: user)
      expect(entry.cache_tags).to eq([described_class.entry(entry.id)])
    end

    it 'purges the chrome and the lists for blog settings' do
      expect(blog.cache_tags).to contain_exactly(described_class::BLOG, described_class::ENTRIES)
    end
  end
end
