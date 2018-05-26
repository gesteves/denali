require 'elasticsearch/model'
class Entry < ApplicationRecord
  include Elasticsearch::Model
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TextHelper
  include Formattable

  has_many :photos, -> { order 'position ASC' }, dependent: :destroy
  belongs_to :blog, touch: true
  belongs_to :user

  validates :title, presence: true

  before_save :set_published_date, if: :is_published?
  before_save :set_entry_slug
  before_create :set_preview_hash

  acts_as_taggable_on :tags, :equipment, :locations, :styles
  acts_as_list scope: :blog

  accepts_nested_attributes_for :photos, allow_destroy: true, reject_if: lambda { |attributes| attributes['source_file'].blank? && attributes['source_url'].blank? && attributes['id'].blank? }

  attr_accessor :invalidate_cloudfront

  settings index: { number_of_shards: 1 }

  after_commit on: [:create] do
    ElasticsearchJob.perform_later(self, 'create')
  end

  after_commit on: [:update] do
    ElasticsearchJob.perform_later(self, 'update')
  end

  after_commit on: [:destroy] do
    ElasticsearchJob.perform_later(self, 'destroy')
  end

  def as_indexed_json(opts = nil)
    self.as_json(only: [:photos_count, :status, :published_at, :created_at, :blog_id, :id], methods: [:plain_body, :plain_title, :es_tags, :es_locations, :es_equipment, :es_captions, :es_styles, :es_keywords])
  end

  def self.published(order = 'published_at DESC')
    where(status: 'published').order(order)
  end

  def self.drafted(order = 'updated_at DESC')
    where(status: 'draft').order(order)
  end

  def self.queued(order = 'position ASC')
    where(status: 'queued').order(order)
  end

  def self.mapped
    joins(:photos).includes(:photos).where(entries: { show_in_map: true, status: 'published' }).where.not(photos: { latitude: nil, longitude: nil })
  end

  def self.text_entries
    where('photos_count = 0')
  end

  def self.photo_entries
    where('photos_count > 0')
  end

  def self.full_search(query, page = 1, per_page = 10)
    search = {
      query: {
        bool: {
          must: [
            { query_string: { query: query, default_operator: 'AND' } }
          ]
        }
      },
      sort: [
        { created_at: 'desc' },
        '_score'
      ],
      size: per_page,
      from: (page.to_i - 1) * per_page
    }
    self.search(search)
  end

  def self.published_search(query, page = 1, per_page = 10)
    search = {
      query: {
        bool: {
          must: [
            { term: { status: 'published' } },
            { range: { photos_count: { gt: 0 } } },
            { multi_match: { query: query, fields: ['plain_*', 'es_*'], type: 'cross_fields', operator: 'and' } }
          ]
        }
      },
      sort: [
        { published_at: 'desc' },
        '_score'
      ],
      size: per_page,
      from: (page.to_i - 1) * per_page
    }
    self.search(search)
  end

  def self.queue_has_published_today?
    published.first.published_at.in_time_zone(Rails.application.config.time_zone).beginning_of_day == Time.now.in_time_zone(Rails.application.config.time_zone).beginning_of_day
  end

  def is_photo?
    !self.photos_count.blank? && self.photos_count > 0
  end

  def is_photoset?
    !self.photos_count.blank? && self.photos_count > 1
  end

  def is_text?
    self.photos_count.blank? || self.photos_count == 0
  end

  def is_single_photo?
    !self.photos_count.blank? && self.photos_count == 1
  end

  def is_queued?
    self.status == 'queued'
  end

  def is_draft?
    self.status == 'draft'
  end

  def is_published?
    self.status == 'published'
  end

  def publish
    self.remove_from_list
    self.status = 'published'
    self.save && self.enqueue_sharing_jobs
  end

  def queue
    unless status == 'published'
      self.insert_at(Entry.queued.size)
      self.status = 'queued'
      self.save
    end
  end

  def draft
    unless status == 'published'
      self.remove_from_list
      self.status = 'draft'
      self.save
    end
  end

  def newer
    date = self.published_at || self.publish_date_for_queued
    Entry.published('published_at ASC').where('published_at > ?', date).where.not(id: self.id).limit(1).first
  end

  def older
    date = self.published_at || self.publish_date_for_queued
    Entry.published.where('published_at < ?', date).where.not(id: self.id).limit(1).first
  end

  def publish_date_for_queued
    days = if Entry.queue_has_published_today?
      self.position
    else
      self.position - 1
    end
    Time.now.in_time_zone(Rails.application.config.time_zone) + days.days
  end

  def related(count = 12)
    start_date = if self.is_published?
      self.published_at.beginning_of_day - 1.year
    elsif self.is_queued?
      self.publish_date_for_queued.beginning_of_day - 1.year
    else
      self.created_at.beginning_of_day - 1.year
    end

    end_date = if self.is_published?
      self.published_at.end_of_day + 1.year
    elsif self.is_queued?
      self.publish_date_for_queued.end_of_day + 1.year
    else
      self.created_at.end_of_day + 1.year
    end

    begin
      search = {
        query: {
          bool: {
            must: [
              { term: { blog_id: self.blog_id } },
              { term: { status: 'published' } },
              { range: { photos_count: { gt: 0 } } },
              { range: { published_at: { gte: start_date, lte: end_date } } }
            ],
            must_not: {
              term: { id: self.id }
            },
            should: [
              { match: { es_tags: { query: self.es_tags } } },
              { match: { es_locations: { query: self.es_locations } } },
              { match: { es_styles: { query: self.es_styles } } }
            ],
            minimum_should_match: 1
          }
        },
        size: count
      }
      Entry.search(search).records.includes(:photos)
    rescue => e
      logger.error "Fetching related entries failed with the following error: #{e}"
      nil
    end
  end

  def formatted_body
    markdown_to_html(self.body)
  end

  def plain_body
    markdown_to_plaintext(self.body)
  end

  def plain_title
    markdown_to_plaintext(self.title)
  end

  def formatted_content(opts = {})
    opts.reverse_merge!(link_title: false)

    content = if opts[:link_title] && opts[:utm].present?
      "[#{self.title}](#{self.permalink_url(opts[:utm])})"
    elsif opts[:link_title]
      "[#{self.title}](#{self.permalink_url})"
    else
      self.title
    end

    content += "\n\n#{self.body}" unless self.body.blank?
    markdown_to_html(content)
  end

  def slug_params
    entry_date = self.published_at || self.updated_at
    year = entry_date.strftime('%Y')
    month = entry_date.strftime('%-m')
    day = entry_date.strftime('%-d')
    id = self.id
    slug = self.slug
    return year, month, day, id, slug
  end

  def permalink_path
    if self.is_published?
      year, month, day, id, slug = self.slug_params
      entry_long_path(year, month, day, id, slug)
    else
      preview_entry_path(self.preview_hash)
    end
  end

  def permalink_url(opts = {})
    opts.reverse_merge!(host: self.blog.domain)
    if self.is_published?
      year, month, day, id, slug = self.slug_params
      entry_long_url(year, month, day, id, slug, url_opts(opts))
    else
      preview_entry_url(self.preview_hash, url_opts(opts))
    end
  end

  def amp_url(opts = {})
    return nil unless self.is_published?
    opts.reverse_merge!(host: self.blog.domain)
    year, month, day, id, slug = self.slug_params
    entry_amp_url(year, month, day, id, slug, url_opts(opts))
  end

  def short_permalink_url(opts = {})
    host = self.blog.short_domain || self.blog.domain
    opts.reverse_merge!(host: host)
    entry_url(self.id, url_opts(opts))
  end

  def enqueue_sharing_jobs
    self.enqueue_slack
    AppleNewsJob.perform_later(self) if self.blog.publish_on_apple_news
    FacebookJob.perform_later(self) if self.post_to_facebook
    FlickrJob.perform_later(self) if self.post_to_flickr
    InstagramJob.perform_later(self) if self.post_to_instagram
    PinterestJob.perform_later(self) if self.post_to_pinterest
    TumblrJob.perform_later(self) if self.post_to_tumblr
    TwitterJob.perform_later(self) if self.post_to_twitter
    true
  end

  def enqueue_slack
    attachment = {
      fallback: "#{self.plain_title} #{self.permalink_url}",
      title: self.plain_title,
      title_link: self.permalink_url
    }
    attachment[:image_url] = self.photos.first.url(w: 800) if self.is_photo?
    attachment[:color] = '#BF0222'
    SlackJob.perform_later(attachments: [attachment])
  end

  def combined_tags
    tags = self.tags + self.equipment + self.locations + self.styles
    tags.uniq { |t| t.slug }
  end

  def combined_tag_list
    self.combined_tags.map(&:name)
  end

  def es_tags
    self.tag_list.join(' ')
  end

  def es_locations
    self.location_list.join(' ')
  end

  def es_equipment
    self.equipment_list.join(' ')
  end

  def es_styles
    self.style_list.join(' ')
  end

  def es_captions
    self.photos.map { |p| p.plain_caption }.reject(&:blank?).join(' ')
  end

  def es_keywords
    self.photos.map { |p| p.keywords }.reject(&:blank?).join(', ')
  end

  def instagram_hashtags(count = 30)
    entry_tags = self.combined_tags.map { |t| t.slug.gsub(/-/, '') }
    instagram_hashtags = YAML.load_file(Rails.root.join('config/hashtags.yml'))['instagram']

    tags = instagram_hashtags['magazines'].sample(5)
    extra_tags = instagram_hashtags['magazines']

    # For each entry tag, add 5 matching Instagram tags to the array
    instagram_hashtags.each do |k, v|
      if entry_tags.include? k
        tags += instagram_hashtags[k].sample(5)
      end
    end

    # We may have room for more Instagram tags, so build a second array with
    # every Instagram tag that matches this entry's tags.
    if tags.uniq.size < count
      instagram_hashtags.each do |k, v|
        if entry_tags.include? k
          extra_tags += instagram_hashtags[k]
        end
      end
    end

    # Shuffle and add them up, remove the duplicates, and grab the first `count`.
    # That way we end up with `count` Instagram hashtags, guaranteeing there are
    # at least a few of each matching entry tag.
    instagram_tags = tags.shuffle + extra_tags.shuffle
    instagram_tags.uniq[0, count].shuffle.map { |t| "##{t}"}.join(' ')
  end

  def instagram_caption
    text = []
    if self.instagram_text.present?
      text << self.instagram_text
    else
      text << self.plain_title
      text << self.plain_body
    end
    text << self.instagram_hashtags
    text.reject(&:blank?).join("\n\n")
  end

  def update_tags
    equipment_tags = []
    location_tags = []
    style_tags = []
    self.photos.each do |p|
      equipment_tags << [p.formatted_make, p.formatted_camera, p.formatted_film]
      style_tags << (p.color? ? "Color" : "Black and White") unless p.color?.nil?
      location_tags  << [p.country, p.locality, p.sublocality, p.neighborhood, p.administrative_area] if self.show_in_map?
    end
    equipment_tags = equipment_tags.flatten.uniq.reject(&:blank?)
    location_tags = location_tags.flatten.uniq.reject(&:blank?)
    style_tags = style_tags.flatten.uniq.reject(&:blank?)
    self.equipment_list = equipment_tags
    self.location_list = location_tags
    self.style_list = style_tags
    self.tag_list.remove(equipment_tags + location_tags + ['Color', 'Black and White'])
    self.save!
  end

  def add_tags(new_tags)
    self.tag_list.add(new_tags, parse: true)
    self.tag_list.remove(self.equipment_list + self.location_list + ['Color', 'Black and White'])
    self.save!
  end

  def to_apple_news_document
    document = AppleNews::Document.new
    document.identifier = self.id.to_s
    document.language = 'en'
    document.title = self.plain_title
    document.metadata = apple_news_metadata
    document.layout = AppleNews::Layout.new(columns: 7, width: 1024, margin: 60, gutter: 20)
    document.component_text_styles = apple_news_component_text_styles
    document.component_layouts = apple_news_component_layouts
    document.text_styles = apple_news_text_styles

    if self.is_single_photo?
      document.components << apple_news_photo_component
    elsif self.is_photoset?
      document.components << apple_news_gallery_component
    end
    document.components << apple_news_divider_component(width: 4) if self.is_photo?
    document.components << apple_news_title_component
    document.components << apple_news_body_component if self.body.present?
    document.components << apple_news_divider_component(layout: 'divider') if self.is_photo?
    document.components << apple_news_meta_component(apple_news_byline)
    document.components << apple_news_meta_component(self.photos.first.exif_string) if self.is_single_photo?
    document.components << apple_news_meta_component(apple_news_tag_list)
    document.components << apple_news_divider_component(width: 4, layout: 'divider')
    document.components << apple_news_map_component if self.show_in_map? && self.photos.count(&:has_location?) > 0

    document
  end

  private

  def url_opts(opts)
    if Rails.env.production?
      opts.reverse_merge!(protocol: Rails.configuration.force_ssl ? 'https' : 'http')
    else
      opts.reverse_merge!(only_path: true)
    end
    opts
  end

  def set_published_date
    if self.is_published? && self.published_at.nil?
      time = Time.now
      self.published_at = time
      self.modified_at  = time
    end
  end

  def set_entry_slug
    if self.slug.blank?
      self.slug = self.title.parameterize
    else
      self.slug = self.slug.parameterize
    end
  end

  def set_preview_hash
    sha256 = Digest::SHA256.new
    self.preview_hash = sha256.hexdigest(Time.now.to_i.to_s)
  end

  def apple_news_component_text_styles
    {
      title: AppleNews::Style::ComponentText.new(
        fontName: 'AvenirNext-Bold',
        fontSize: 32,
        textColor: '#444'
      ),
      body: AppleNews::Style::ComponentText.new(
        fontName: 'Palatino-Roman',
        textColor: '#444',
        fontSize: 16,
        linkStyle: AppleNews::Style::Text.new(textColor: '#BF0222')
      ),
      meta: AppleNews::Style::ComponentText.new(
        fontName: 'AvenirNext-Regular',
        textColor: '#666',
        fontSize: 12,
        lineHeight: 24,
        textAlignment: 'center',
        hyphenation: false
      )
    }
  end

  def apple_news_component_layouts
    {
      default: AppleNews::ComponentLayout.new(
        columnSpan: 5,
        columnStart: 1
      ),
      title: AppleNews::ComponentLayout.new(
        columnSpan: 5,
        columnStart: 1,
        margin: 36
      ),
      titleOnly: AppleNews::ComponentLayout.new(
        columnSpan: 5,
        columnStart: 1,
        margin: { top: 36, bottom: 0 }
      ),
      photo: AppleNews::ComponentLayout.new(
        ignoreDocumentMargin: true,
        margin: { top: 0, bottom: 36 }
      ),
      divider: AppleNews::ComponentLayout.new(
        margin: 36
      ),
      map: AppleNews::ComponentLayout.new(
        margin: { top: 0, bottom: 36 }
      )
    }
  end

  def apple_news_text_styles
    {
      'default-tag-blockquote': {
        fontName: 'Palatino-Italic',
        textColor: '#666'
      }
    }
  end

  def apple_news_metadata
    excerpt = if self.is_photo?
      if self.body.present?
        truncate(self.plain_body, length: 200)
      elsif self.photos.first.alt_text.present?
        self.photos.first.alt_text
      end
    else
      truncate(self.plain_body, length: 200)
    end

    metadata = AppleNews::Metadata.new
    metadata.authors = [self.user.name]
    metadata.canonical_url = self.permalink_url
    metadata.date_published = self.published_at.utc.strftime('%FT%TZ') if self.is_published?
    metadata.date_modified = self.modified_at.utc.strftime('%FT%TZ') if self.is_published?
    metadata.keywords = self.combined_tags[0, 50].map(&:name)
    metadata.thumbnail_url = self.photos.first.url(w: 2732) if self.is_photo?
    metadata.excerpt = excerpt
    metadata
  end

  def apple_news_photo_component
    photo = self.photos.first
    component = AppleNews::Component::Photo.new
    component.caption = photo.plain_caption
    component.url = photo.url(w: 2732)
    component.layout = 'photo'
    component
  end

  def apple_news_gallery_component
    component = AppleNews::Component::Gallery.new
    component.items = self.photos.map { |p| AppleNews::Property::GalleryItem.new(caption: p.plain_caption, URL: p.url(w: 2732)) }
    component.layout = 'photo'
    component
  end

  def apple_news_divider_component(opts = {})
    opts.reverse_merge!(width: 1, color: '#EEE')
    component = AppleNews::Component::Divider.new
    component.stroke = AppleNews::Style::Stroke.new(color: opts[:color], width: opts[:width])
    component.layout = opts[:layout] if opts[:layout].present?
    component
  end

  def apple_news_title_component
    component = AppleNews::Component::Title.new
    component.text = self.plain_title
    component.text_style = 'title'
    component.layout = self.body.present? ? 'title' : 'titleOnly'
    component
  end

  def apple_news_body_component
    component = AppleNews::Component::Body.new
    component.format = 'html'
    component.text = self.formatted_body
    component.text_style = 'body'
    component.layout = 'default'
    component
  end

  def apple_news_meta_component(text, opts = {})
    component = AppleNews::Component::Body.new
    component.format = 'html'
    component.text = text
    component.text_style = 'meta'
    component.layout = 'default'
    component
  end

  def apple_news_map_component
    component = AppleNews::Component::Map.new
    photos = self.photos.select(&:has_location?)
    component.items = photos.map { |p| AppleNews::Property::MapItem.new(latitude: p.latitude, longitude: p.longitude, caption: p.plain_caption) }
    component.layout = 'map'
    component
  end

  def apple_news_tag_list
    self.combined_tags.sort_by { |t| t.name }.map { |t| link_to("##{t.name.downcase}", Rails.application.routes.url_helpers.tag_url(t.slug, host: self.blog.domain)) }.join(' ')
  end

  def apple_news_byline
    if self.is_published?
      "By #{self.user.name} · Published on #{link_to self.published_at.strftime('%B %-d, %Y'), self.permalink_url}"
    elsif self.is_queued?
      "By #{self.user.name} · Queued for #{link_to self.publish_date_for_queued.strftime('%B %-d, %Y'), self.permalink_url}"
    else
      "By #{self.user.name} · Updated on #{link_to self.updated_at.strftime('%B %-d, %Y'), self.permalink_url}"
    end
  end
end
