require 'test_helper'

class TagCustomizationTest < ActiveSupport::TestCase
  test 'should not save tag customization without tags' do
    blog = blogs(:allencompassingtrip)
    tc = TagCustomization.new(blog: blog, instagram_hashtags: '#foo', flickr_groups: 'bar')
    assert_not tc.save
    tc.tag_list = 'Foo'
    assert tc.save
  end

  test 'should not save tag customization without flickr groups and hashtags' do
    blog = blogs(:allencompassingtrip)
    tc = TagCustomization.new(blog: blog, tag_list: 'Foo')
    assert_not tc.save
    tc.instagram_hashtags = '#foo'
    assert tc.save
  end

  test 'should not save tag customization if tags are not unique' do
    blog = blogs(:allencompassingtrip)
    tc = TagCustomization.new(blog: blog, tag_list: 'Foo, Bar', instagram_hashtags: '#foo')
    tc.save!

    tc_1 = TagCustomization.new(blog: blog, tag_list: 'Foo', instagram_hashtags: '#foo')
    assert tc_1.save
    tc_2 = TagCustomization.new(blog: blog, tag_list: 'Bar, Foo', instagram_hashtags: '#foo')
    assert_not tc_2.save
  end
end
