require 'rails_helper'

RSpec.describe Admin::EntriesHelper, type: :helper do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }

  describe '#admin_entry_cache_key' do
    it 'is just the entry for entries that are not queued' do
      entry = create(:entry, :published, blog: blog, user: user)
      expect(view_helper.admin_entry_cache_key(entry)).to eq(entry)
    end

    # The queued date moves with the clock and the schedule, neither of which
    # touches the entry, so a card cached yesterday would show yesterday's date.
    it 'changes from one day to the next for a queued entry' do
      entry = create(:entry, :queued, blog: blog, user: user)
      today = view_helper.admin_entry_cache_key(entry)

      travel 1.day do
        expect(view_helper.admin_entry_cache_key(entry)).not_to eq(today)
      end
    end

    it 'changes when a publishing time passes' do
      entry = create(:entry, :queued, blog: blog, user: user)
      create(:publish_schedule, blog: blog, hour: 10)

      travel_to Time.current.in_time_zone(blog.time_zone).change(hour: 9) do
        before_key = view_helper.admin_entry_cache_key(entry)
        travel 2.hours
        expect(view_helper.admin_entry_cache_key(entry)).not_to eq(before_key)
      end
    end
  end

  # The helper memoizes per view, so each check after time moves needs a fresh one.
  def view_helper
    view = Class.new(ActionView::Base) { include Admin::EntriesHelper }.empty
    view.instance_variable_set(:@photoblog, Blog.find(blog.id))
    view
  end
end
