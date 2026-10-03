require 'rails_helper'

RSpec.describe 'Admin entry form', type: :system do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  # The form goes through Turbo, and the flash has to survive the visit: the
  # notifications container used to be data-turbo-permanent, which kept the
  # previous page's (empty) copy and dropped the new one.
  it 'saves an entry and shows the flash on the page Turbo lands on' do
    visit new_admin_entry_path
    fill_in 'entry_title', with: 'A new draft'
    find('[data-radio-tab-value="draft"]').click
    click_button 'Save entry'

    expect(page).to have_css('.notification', text: 'Your entry was saved!')
    expect(Entry.find_by(title: 'A new draft')).to be_is_draft
  end

  # Turbo only re-renders a form submission answered with a 4xx. (The title is
  # required in the browser too, so this skips that check to reach the server.)
  it 'shows the form again when the entry is invalid' do
    visit new_admin_entry_path
    page.execute_script("document.querySelector('form[data-controller~=entry-form]').noValidate = true")
    fill_in 'entry_title', with: ''
    click_button 'Save entry'

    expect(page).to have_css('.notification', text: 'couldn’t be saved')
  end
end
