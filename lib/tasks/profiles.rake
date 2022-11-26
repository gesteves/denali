namespace :profiles do
  desc 'Set up a profile for the existing users'
  task :setup => :environment do
    blog = Blog.first
    User.where.not(provider: nil).each do |user|
      next if user.profile.present?
      profile = Profile.new
      profile.name = user.name
      profile.username = user.name.parameterize
      profile.email = user.email
      profile.bio = blog.about
      profile.meta_description = blog.meta_description
      profile.flickr = blog.flickr
      profile.instagram = blog.instagram
      profile.tumblr = blog.tumblr
      profile.user = user
      profile.save!
    end
  end
end
