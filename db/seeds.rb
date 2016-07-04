# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

Blog.create(
  name: ENV['site_name'],
  domain: ENV['site_domain'],
  short_domain: ENV['site_short_domain'],
  description: ENV['site_description'],
  posts_per_page: ENV['site_posts_per_page']
  about: ENV['site_about']
)
