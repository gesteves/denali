namespace :tag_customizations do
  task :generate => :environment do
    instagram_hashtags = YAML.load_file(Rails.root.join('config/hashtags.yml'))['instagram']
    flickr_groups = YAML.load_file(Rails.root.join('config/flickr_groups.yml'))

    if instagram_hashtags.present? && flickr_groups.present?
      blog = Blog.first
      TagCustomization.destroy_all
      tags = ActsAsTaggableOn::Tag.all
      tags.each do |tag|
        slug = tag.slug.gsub(/-/, '')
        hashtags = instagram_hashtags[slug]
        groups = flickr_groups[slug]
        if hashtags.present? || groups.present?
          puts "#{tag.name.upcase}"
          puts hashtags.map { |h| "##{h}"}.join("\n") if hashtags.present?
          puts groups.join("\n") if groups.present?
          puts "\n"

          tag_customization = TagCustomization.new(instagram_hashtags: '', flickr_groups: '', blog: blog)
          tag_customization.instagram_hashtags = hashtags.map { |h| "##{h}"}.join("\n") if hashtags.present?
          tag_customization.flickr_groups = groups.join("\n") if groups.present?
          tag_customization.tag_list.add(tag.name)
          tag_customization.save!
        end
      end
    end
  end
end
