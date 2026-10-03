require 'rails_helper'

RSpec.describe 'Admin queue', type: :system do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }

  before do
    sign_in_as(user)
    create_list(:entry, 2, :queued, blog: blog, user: user)
  end

  # With no publishing schedule there's no date to show. The controller used to
  # read the wrong property here and throw on the invalid date instead.
  it 'shows TBD for every queued entry when nothing is scheduled' do
    visit admin_entries_queued_organize_path

    expect(page).to have_css('[data-timestamp]', text: 'TBD', count: 2)
  end

  it 'works out publish dates from the schedule' do
    create(:publish_schedule, blog: blog, hour: 23)
    visit admin_entries_queued_organize_path

    expect(page).to have_css('[data-timestamp]', count: 2)
    expect(page).not_to have_css('[data-timestamp]', text: 'TBD')
  end
end
