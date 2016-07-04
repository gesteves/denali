# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

<<<<<<< HEAD
Blog.create(
  name: ENV['site_name'],
  domain: ENV['site_domain'],
  short_domain: ENV['site_short_domain'],
  description: ENV['site_description'],
  posts_per_page: ENV['site_posts_per_page'],
  about: ENV['site_about']
)
=======
Blog.create(name: 'Clif and Allie', domain: 'clifandallie.com', short_domain: 'aetrip.co', description: 'Denver to Durango 2016.', posts_per_page: 12, about: 'Denver to Durango 2016. Previously AT NOBO 2015.', copyright: 'Clif Reeder')
>>>>>>> e89e776... Change until I can import
