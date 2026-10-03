require 'rails_helper'

RSpec.describe AdminHelper, type: :helper do
  describe '#pluralize_with_delimiter' do
    it 'pluralizes and adds thousands separators' do
      expect(helper.pluralize_with_delimiter('entry', 1)).to eq('1 entry')
      expect(helper.pluralize_with_delimiter('entry', 12_345)).to eq('12,345 entries')
    end
  end

  describe '#last_shared_tag' do
    it 'says never, in green, for something never shared' do
      html = helper.last_shared_tag(nil)
      expect(html).to include('Never')
      expect(html).to include('tag is-success')
    end

    # Recently shared entries are flagged so they aren't shared again too soon.
    it 'flags a recent share in red' do
      html = helper.last_shared_tag(2.days.ago)
      expect(html).to include('2 days ago')
      expect(html).to include('tag is-danger')
    end

    it 'turns green again after a year' do
      expect(helper.last_shared_tag(13.months.ago)).to include('tag is-success')
    end
  end

  describe '#shares_count_tag' do
    it 'shows the count' do
      expect(helper.shares_count_tag(7)).to include('<span class="tag">7</span>')
    end
  end

  describe '#icon' do
    it 'renders the icon with its label' do
      html = helper.icon('Edit', 'fas fa-pen')
      expect(html).to include('<i class="fas fa-pen"></i>')
      expect(html).to include('<span>Edit</span>')
    end
  end
end
