class AppleNewsJob < ApplicationJob
  include ActionView::Helpers::UrlHelper

  def perform(entry)
    if Rails.env.production?
      return if !entry.is_published? || ENV['apple_news_channel_id'].blank?
      # TODO: Uncomment when entries have apple_news_id column
      # article = if entry.apple_news_id.present?
      #   AppleNews::Article.new(entry.apple_news_id)
      # else
      #   AppleNews::Article.new
      # end

      # TODO: Remove when entries have apple_news_id column
      article = AppleNews::Article.new

      article.document = generate_document(entry)

      response = article.save!
      if response.is_a?(Array)
        raise response
      elsif article.id.present? && article.id != entry.apple_news_id
        # TODO: Uncomment when entries have apple_news_id column
        # entry.apple_news_id = article.id
        # entry.save
      end
    elsif Rails.env.development?
      File.open("tmp/article.json",'w'){ |f| f << generate_document(entry).as_json.to_json }
    end
  end

  private

  def generate_document(entry)
    document = AppleNews::Document.new
    document.identifier = entry.id.to_s
    document.language = 'en'
    document.title = entry.plain_title
    document.metadata = metadata(entry)
    document.layout = AppleNews::Layout.new(columns: 7, width: 1024, margin: 60, gutter: 20)
    document.component_text_styles = component_text_styles
    document.component_layouts = component_layouts
    document.text_styles = text_styles

    if entry.is_single_photo?
      document.components << photo_component(entry)
    elsif entry.is_photoset?
      document.components << gallery_component(entry)
    end
    document.components << divider_component(width: 4) if entry.is_photo?
    document.components << title_component(entry)
    document.components << body_component(entry) if entry.body.present?
    document.components << divider_component(layout: 'divider') if entry.is_photo?
    document.components << meta_component(byline(entry))
    document.components << meta_component(exif(entry.photos.first)) if entry.is_single_photo?
    document.components << meta_component(tag_list(entry))
    document.components << divider_component(width: 4, layout: 'divider')
    document.components << map_component(entry) if entry.show_in_map? && entry.photos.count(&:has_location?) > 0

    document
  end

  def component_text_styles
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

  def component_layouts
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
        margin: { top: 36, bottom: 0}
      ),
      photo: AppleNews::ComponentLayout.new(
        ignoreDocumentMargin: true,
        margin: { top: 0, bottom: 36}
      ),
      divider: AppleNews::ComponentLayout.new(
        margin: 36
      ),
      map: AppleNews::ComponentLayout.new(
        margin: { top: 0, bottom: 36}
      )
    }
  end

  def text_styles
    {
      'default-tag-blockquote': {
        fontName: 'Palatino-Italic',
        textColor: '#666'
      }
    }
  end

  def metadata(entry)
    metadata = AppleNews::Metadata.new
    metadata.authors = [entry.user.name]
    metadata.canonical_url = entry.permalink_url
    metadata.date_published = entry.published_at.utc.strftime('%FT%TZ')
    metadata.date_modified = entry.modified_at.utc.strftime('%FT%TZ')
    metadata.keywords = entry.combined_tags[0, 50].map(&:name)
    metadata.thumbnail_url = entry.photos.first.url(w: 2732)
    metadata.excerpt = excerpt(entry)
    metadata
  end

  def photo_component(entry)
    photo = entry.photos.first
    component = AppleNews::Component::Photo.new
    component.caption = photo.plain_caption
    component.url = photo.url(w: 2732)
    component.layout = 'photo'
    component
  end

  def gallery_component(entry)
    component = AppleNews::Component::Gallery.new
    component.items = entry.photos.map { |p| AppleNews::Property::GalleryItem.new(caption: p.plain_caption, URL: p.url(w: 2732)) }
    component.layout = 'photo'
    component
  end

  def title_component(entry)
    component = AppleNews::Component::Title.new
    component.text = entry.plain_title
    component.text_style = 'title'
    component.layout = entry.body.present? ? 'title' : 'titleOnly'
    component
  end

  def body_component(entry)
    component = AppleNews::Component::Body.new
    component.format = 'html'
    component.text = entry.formatted_body
    component.text_style = 'body'
    component.layout = 'default'
    component
  end

  def meta_component(text, opts = {})
    component = AppleNews::Component::Body.new
    component.format = 'html'
    component.text = text
    component.text_style = 'meta'
    component.layout = 'default'
    component
  end

  def map_component(entry)
    component = AppleNews::Component::Map.new
    photos = entry.photos.select(&:has_location?)
    component.items = if photos.size > 1
      component.items = entry.photos.select(&:has_location?).map { |p| AppleNews::Property::MapItem.new(latitude: p.latitude, longitude: p.longitude, caption: p.plain_caption) }
    else
      component.items = entry.photos.select(&:has_location?).map { |p| AppleNews::Property::MapItem.new(latitude: p.latitude, longitude: p.longitude) }
    end
    component.layout = 'map'
    component
  end

  def divider_component(opts = {})
    opts.reverse_merge!(width: 1, color: '#EEE')
    component = AppleNews::Component::Divider.new
    component.stroke = AppleNews::Style::Stroke.new(color: opts[:color], width: opts[:width])
    component.layout = opts[:layout] if opts[:layout].present?
    component
  end

  def byline(entry)
    "By #{entry.user.name} · Published on #{link_to entry.published_at.strftime('%B %-d, %Y'), entry.permalink_url}"
  end

  def exif(photo)
    items = []
    items << photo.taken_with

    unless photo.is_phone_camera?
      items << photo.focal_length_with_unit

      if photo.exposure.present? && photo.f_number.present?
        items << "#{photo.formatted_exposure} at #{photo.formatted_aperture}"
      elsif photo.exposure.present?
        items << photo.formatted_exposure
      elsif photo.f_number.present?
        items << photo.formatted_aperture
      end

      if photo.iso.present?
        items << "ISO #{photo.iso}"
      end
    end

    items.reject(&:blank?).join(' · ')
  end

  def excerpt(entry)
    if entry.is_photo?
      if entry.photos.first.alt_text.present?
        entry.photos.first.alt_text
      elsif entry.body.present?
        entry.plain_body
      end
    else
      entry.plain_body
    end
  end

  def tag_list(entry)
    entry.combined_tags.sort_by { |t| t.name }.map { |t| link_to("##{t.name.downcase}", Rails.application.routes.url_helpers.tag_url(t.slug, host: entry.blog.domain)) }.join(' ')
  end
end
