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
      profile.user = user
      profile.save!
    end
  end
end
