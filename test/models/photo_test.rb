require 'test_helper'

class PhotoTest < ActiveSupport::TestCase

  test 'updating a photo should update entry' do
    entry = entries(:peppers)

    original_updated_at = entry.updated_at

    entry.update! photos_attributes: { '0': { alt_text: 'Foo', id: entry.photos.first.id } }

    entry.reload

    new_updated_at = entry.updated_at
    assert_not_equal original_updated_at, new_updated_at
  end
end
