class AppleNewsJob < ApplicationJob
  include ActionView::Helpers::UrlHelper

  def perform(entry)
    return if !entry.is_published? || ENV['apple_news_channel_id'].blank? || !Rails.env.production?

    # article = if entry.apple_news_id.present?
    #   AppleNews::Article.new(entry.apple_news_id)
    # else
    #   AppleNews::Article.new
    # end

    article = AppleNews::Article.new
    article.document = generate_document(entry)

    response = article.save!
    if response
      # entry.apple_news_id = article.id
      # entry.save
    else
      raise response
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

    entry.photos.map { |p| document.components << photo_component(p) }
    document.components << divider_component(width: 4) if entry.is_photo?
    document.components << title_component(entry)
    document.components << body_component(entry) if entry.body.present?
    document.components << divider_component(layout: 'divider') if entry.is_photo?
    document.components << meta_component(published_on(entry))
    document.components << meta_component(exif(entry.photos.first)) if entry.is_single_photo?
    document.components << meta_component(tag_list(entry), layout: 'tags')

    document
  end

  def component_text_styles
    {
      title: AppleNews::Style::ComponentText.new(
        fontName: 'AvenirNext-Regular',
        fontSize: 28,
        textColor: '#444444'
      ),
      body: AppleNews::Style::ComponentText.new(
        fontName: 'Palatino-Roman',
        textColor: '#444444',
        fontSize: 16,
        linkStyle: AppleNews::Style::Text.new(textColor: '#BF0222')
      ),
      meta: AppleNews::Style::ComponentText.new(
        fontName: 'AvenirNext-Italic',
        textColor: '#666666',
        fontSize: 14,
        textAlignment: 'center'
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
      photo: AppleNews::ComponentLayout.new(
        ignoreDocumentMargin: true,
        margin: { top: 0, bottom: 36}
      ),
      divider: AppleNews::ComponentLayout.new(
        margin: 36
      ),
      tags: AppleNews::ComponentLayout.new(
        columnSpan: 5,
        columnStart: 1,
        margin: { top: 0, bottom: 36}
      )
    }
  end

  def metadata(entry)
    metadata = AppleNews::Metadata.new
    metadata.authors = [entry.user.name]
    metadata.canonical_url = entry.permalink_url
    metadata.date_published = entry.published_at.utc.strftime('%FT%TZ')
    metadata.date_modified = entry.modified_at.utc.strftime('%FT%TZ')
    metadata.keywords = entry.combined_tags.map(&:name)
    metadata.thumbnail_url = entry.photos.first.url(w: 2732)
    metadata.excerpt = excerpt(entry)
    metadata
  end

  def photo_component(photo)
    component = AppleNews::Component::Photo.new
    component.caption = photo.plain_caption
    component.url = photo.url(w: 2732)
    component.layout = 'photo'
    component
  end

  def title_component(entry)
    component = AppleNews::Component::Title.new
    component.text = entry.plain_title
    component.text_style = 'title'
    component.layout = 'title'
    component
  end

  def body_component(entry)
    component = AppleNews::Component::Body.new
    component.format = 'markdown'
    component.text = entry.body
    component.text_style = 'body'
    component.layout = 'default'
    component
  end

  def meta_component(text, opts = {})
    opts.reverse_merge!(layout: 'default')
    component = AppleNews::Component::Body.new
    component.format = 'html'
    component.text = text
    component.text_style = 'meta'
    component.layout = opts[:layout]
    component
  end

  def divider_component(opts = {})
    opts.reverse_merge!(width: 1, color: '#EEE')
    component = AppleNews::Component::Divider.new
    component.stroke = AppleNews::Style::Stroke.new(color: opts[:color], width: opts[:width])
    component.layout = opts[:layout] if opts[:layout].present?
    component
  end

  def published_on(entry)
    "Published on #{link_to entry.published_at.strftime('%B %-d, %Y'), entry.permalink_url}"
  end

  def exif(photo)
    items = []
    if photo.make.present? && photo.model.present?
      text = "Taken with #{article(photo.make)} #{photo.formatted_camera}"
      if photo.is_film?
        text += " #{on photo.formatted_film}"
      end
      items << text
    end

    unless photo.is_phone_camera?
      if photo.focal_length.present?
        items << "#{photo.focal_length} mm"
      end

      if photo.exposure.present? && photo.f_number.present?
        items << "#{exposure(photo.exposure)} at f/#{aperture(photo.f_number)}"
      elsif photo.exposure.present?
        items << exposure(photo.exposure)
      elsif photo.f_number.present?
        items << "f/#{aperture(photo.f_number)}"
      end

      if photo.iso.present?
        items << "ISO #{photo.iso }"
      end
    end

    items.join(' · ')
  end

  def article(word)
    %w(a e i o u).include?(word[0].downcase) ? 'an' : 'a'
  end

  def aperture(f_number)
    "%g" % ("%.2f" % f_number)
  end

  def exposure(exposure)
    exposure = exposure.to_r
    formatted = exposure >= 1 ? "%g" % ("%.2f" % exposure) : exposure
    "#{formatted}″"
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
