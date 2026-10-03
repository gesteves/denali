require 'rails_helper'

RSpec.describe 'Infinite scroll', type: :system do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }

  before do
    blog.update!(posts_per_page: 2)
    5.times do |i|
      entry = create(:entry, :published, :with_photo, blog: blog, user: user, published_at: i.days.ago)
      entry.photos.each { |photo| attach_image_to_photo(photo) }
    end
  end

  # The pages here are short enough to leave the spinner in view, so this also
  # covers the controller looking again after each page rather than waiting
  # for the spinner to scroll back into view.
  it 'appends the following pages while the spinner is in view' do
    visit root_path

    expect(page).to have_css('.entry-list__item', count: 5)
    expect(page).to have_no_css('[data-infinite-scroll-target="spinner"]')
  end
end
