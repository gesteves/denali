# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

Blog.create(
  name: Rails.application.config.site['name'],
  domain: Rails.application.config.site['domain'],
  short_domain: Rails.application.config.site['short_domain'],
  description: Rails.application.config.site['description'],
  posts_per_page: Rails.application.config.site['posts_per_page']
  about: Rails.application.config.site['about']
)
