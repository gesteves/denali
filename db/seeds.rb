# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

Blog.create(name: "Mr. X's Web Page", description: "All The Muck That's Fit To Rake", posts_per_page: 12, about: 'This is a blog.', copyright: 'Homer Simpson')
