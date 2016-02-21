require 'test_helper'

class BlogTest < ActiveSupport::TestCase
  test 'creating an entry touches the blog' do
    blog = blogs(:allencompassingtrip)
    initial_date = blog.updated_at
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'published')
    entry.blog = blog
    entry.save
    final_date = blog.updated_at
    assert_not_equal initial_date, final_date
  end
end
