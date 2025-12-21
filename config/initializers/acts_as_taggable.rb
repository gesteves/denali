ActsAsTaggableOn.remove_unused_tags = true
ActsAsTaggableOn::Tag.class_eval do
  before_save { |tag| tag.slug = name.parameterize if name_changed? }

  def to_param
    slug
  end

  # Default contexts for filtering tags in discovery features
  # Equipment/styles tags are so common they overwhelm other results (every photo is color or B&W,
  # every photo has a camera brand, etc.), so we exclude them by default from discovery features.
  DEFAULT_CONTEXTS = ['tags', 'locations'].freeze
  DEFAULT_EXCLUDE_CONTEXTS = ['equipment', 'styles'].freeze

  # Scope to filter tags by context
  # @param contexts [Array<String>, nil] Only include tags used in these contexts (nil = all)
  # @param exclude_contexts [Array<String>, nil] Exclude tags used in these contexts (nil = none)
  scope :for_contexts, ->(contexts: nil, exclude_contexts: nil) {
    return all if contexts.nil? && exclude_contexts.nil?

    valid_tag_ids = if contexts.present?
      ActsAsTaggableOn::Tagging
        .where(context: contexts)
        .distinct
        .pluck(:tag_id)
    else
      pluck(:id)
    end

    excluded_tag_ids = if exclude_contexts.present?
      ActsAsTaggableOn::Tagging
        .where(context: exclude_contexts)
        .distinct
        .pluck(:tag_id)
    else
      []
    end

    where(id: valid_tag_ids - excluded_tag_ids)
  }

  # Convenience scope using the default contexts (excludes equipment/styles)
  scope :browsable, -> {
    for_contexts(contexts: DEFAULT_CONTEXTS, exclude_contexts: DEFAULT_EXCLUDE_CONTEXTS)
  }

  # Most popular tags by usage count
  # @param limit [Integer] Maximum number of tags to return
  # @param contexts [Array<String>, nil] Only include tags from these contexts (default: tags, locations)
  # @param exclude_contexts [Array<String>, nil] Exclude tags from these contexts (default: equipment, styles)
  def self.popular(limit: 10, contexts: DEFAULT_CONTEXTS, exclude_contexts: DEFAULT_EXCLUDE_CONTEXTS)
    for_contexts(contexts: contexts, exclude_contexts: exclude_contexts)
      .order(taggings_count: :desc)
      .limit(limit)
  end

  # Most recently used tags (by most recent tagging date)
  # @param limit [Integer] Maximum number of tags to return
  # @param contexts [Array<String>, nil] Only include tags from these contexts (default: tags, locations)
  # @param exclude_contexts [Array<String>, nil] Exclude tags from these contexts (default: equipment, styles)
  def self.most_recently_used(limit: 10, contexts: DEFAULT_CONTEXTS, exclude_contexts: DEFAULT_EXCLUDE_CONTEXTS)
    for_contexts(contexts: contexts, exclude_contexts: exclude_contexts)
      .joins(:taggings)
      .group('tags.id')
      .order('MAX(taggings.created_at) DESC')
      .limit(limit)
  end

  # Find tags that frequently co-occur with the given tag using Elasticsearch
  # Returns tags ordered by how often they appear together with the source tag
  # @param tag [ActsAsTaggableOn::Tag, String] The tag to find related tags for
  # @param limit [Integer] Maximum number of tags to return
  # @param contexts [Array<String>, nil] Only include tags from these contexts (default: tags, locations)
  # @param exclude_contexts [Array<String>, nil] Exclude tags from these contexts (default: equipment, styles)
  def self.related_to(tag, limit: 10, contexts: DEFAULT_CONTEXTS, exclude_contexts: DEFAULT_EXCLUDE_CONTEXTS)
    return [] unless tag.present?

    tag_name = tag.is_a?(ActsAsTaggableOn::Tag) ? tag.name : tag.to_s

    search_def = {
      size: 0,
      query: {
        bool: {
          must: [
            { term: { status: 'published' } },
            { term: { tag_names: tag_name } }
          ]
        }
      },
      aggs: {
        co_occurring_tags: {
          terms: {
            field: 'tag_names',
            size: limit * 3, # Fetch extra to account for filtering
            exclude: tag_name
          }
        }
      }
    }

    results = Entry.search(search_def)
    return [] unless results.response.aggregations&.co_occurring_tags&.buckets

    tag_names = results.response.aggregations.co_occurring_tags.buckets.map { |b| b['key'] }
    return [] if tag_names.empty?

    # Filter by contexts and preserve ES frequency order
    tags_by_name = for_contexts(contexts: contexts, exclude_contexts: exclude_contexts)
      .where(name: tag_names)
      .index_by(&:name)
    tag_names.map { |name| tags_by_name[name] }.compact.take(limit)
  end

  # Find tags matching a search query using fuzzy text matching and synonyms
  # Useful for suggesting tags when a search returns no results.
  # By default includes ALL tags (including equipment/styles) because if someone
  # searches "b&w", we want to show them the "black & white" tag.
  # Leverages synonyms defined in config/search.yml via the search_analyzer on es_tags.
  # @param query [String] The search query
  # @param limit [Integer] Maximum number of tags to return
  # @param contexts [Array<String>, nil] Only include tags from these contexts (default: nil = all)
  # @param exclude_contexts [Array<String>, nil] Exclude tags from these contexts (default: nil = none)
  def self.matching(query, limit: 10, contexts: nil, exclude_contexts: nil)
    return [] if query.blank?

    search_def = {
      size: 0,
      query: {
        bool: {
          must: [
            { term: { status: 'published' } }
          ],
          should: [
            # Exact match on tag names (highest priority)
            { term: { tag_names: { value: query, boost: 3 } } },
            # Fuzzy match on tag text (uses search_analyzer with synonyms)
            { match: { es_tags: { query: query, fuzziness: 'AUTO', boost: 2 } } },
            # Match on tag slugs (handles hyphenated searches)
            { match: { es_tag_slugs: { query: query.parameterize.gsub('-', ''), fuzziness: 'AUTO' } } }
          ],
          minimum_should_match: 1
        }
      },
      aggs: {
        matching_tags: {
          terms: {
            field: 'tag_names',
            size: limit * 3 # Fetch extra to account for filtering
          }
        }
      }
    }

    results = Entry.search(search_def)
    return [] unless results.response.aggregations&.matching_tags&.buckets

    tag_names = results.response.aggregations.matching_tags.buckets.map { |b| b['key'] }
    return [] if tag_names.empty?

    # Filter by contexts (if specified) and preserve ES frequency order
    tags_by_name = for_contexts(contexts: contexts, exclude_contexts: exclude_contexts)
      .where(name: tag_names)
      .index_by(&:name)
    tag_names.map { |name| tags_by_name[name] }.compact.take(limit)
  end

  # Instance method: find tags related to this tag
  # @param limit [Integer] Maximum number of tags to return
  # @param contexts [Array<String>, nil] Only include tags from these contexts (default: tags, locations)
  # @param exclude_contexts [Array<String>, nil] Exclude tags from these contexts (default: equipment, styles)
  def related_tags(limit: 10, contexts: DEFAULT_CONTEXTS, exclude_contexts: DEFAULT_EXCLUDE_CONTEXTS)
    self.class.related_to(self, limit: limit, contexts: contexts, exclude_contexts: exclude_contexts)
  end
end
