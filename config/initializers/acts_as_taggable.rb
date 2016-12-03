ActsAsTaggableOn.remove_unused_tags = true
ActsAsTaggableOn.force_lowercase = true
ActsAsTaggableOn::Tag.class_eval do
  before_save { |tag| tag.slug = name.parameterize if name_changed? }

  def to_param
    slug
  end
end
