class AppleNewsJob < ApplicationJob

  def perform(entry)
    return if !entry.is_published? || ENV['apple_news_channel_id'].blank? #|| !Rails.env.production?
    article = generate_article(entry)
    response = article.save!
    if response
      # entry.apple_news_id = article.id
      # entry.save
    else
      raise response
    end
  end

  private

  def generate_article(entry)
    document = AppleNews::Document.new
    document.identifier = entry.id.to_s
    document.language = 'en'
    document.title = entry.plain_title

    document.layout = AppleNews::Layout.new(
      columns: 7,
      width: 1024
    )

    document.metadata = AppleNews::Metadata.new(
      authors: [entry.user.name],
      canonicalURL: entry.permalink_url,
      datePublished: entry.published_at.utc.strftime('%FT%TZ'),
      dateModified: entry.modified_at.utc.strftime('%FT%TZ'),
      keywords: entry.combined_tags.map(&:name),
      thumbnailURL: entry.photos.first.url(w: 2732),
      excerpt: excerpt(entry)
    )

    entry.photos.each do |p|
      document.components << AppleNews::Component::Photo.new(
        caption: p.plain_caption,
        URL: p.url(w: 2732),
        layout: AppleNews::ComponentLayout.new(
          ignoreDocumentMargin: true,
          margin: { top: 0, bottom: 36}
        )
      )
    end

    if entry.is_photo?
      document.components << AppleNews::Component::Divider.new(
        stroke: AppleNews::Style::Stroke.new(color: '#EEEEEE', width: 4)
      )
    end

    document.components << AppleNews::Component::Title.new(
      text: entry.plain_title,
      textStyle: AppleNews::Style::ComponentText.new(
        fontName: 'AvenirNext-Regular',
        fontSize: 28,
        textColor: '#444444'
      ),
      layout: AppleNews::ComponentLayout.new(
        margin: 36,
        columnSpan: 5,
        columnStart: 1
      )
    )
    if entry.body.present?
      document.components << AppleNews::Component::Body.new(
        format: 'markdown',
        text: entry.body,
        textStyle: AppleNews::Style::ComponentText.new(
          fontName: 'Palatino-Roman',
          textColor: '#444444',
          fontSize: 16,
          linkStyle: AppleNews::Style::Text.new(textColor: '#BF0222')
        ),
        layout: AppleNews::ComponentLayout.new(
          columnSpan: 5,
          columnStart: 1
        )
      )
    end

    document.components << AppleNews::Component::Divider.new(
      stroke: AppleNews::Style::Stroke.new(color: '#EEEEEE', width: 1),
      layout: AppleNews::ComponentLayout.new(
        margin: 36
      )
    )

    document.components << AppleNews::Component::Body.new(
      format: 'html',
      text: "Published on <a href=\"#{entry.permalink_url}\">#{entry.published_at.strftime('%B %-d, %Y')}</a>",
      textStyle: AppleNews::Style::ComponentText.new(
        fontName: 'AvenirNext-Italic',
        textColor: '#666666',
        fontSize: 14,
        textAlignment: 'center'
      ),
      layout: AppleNews::ComponentLayout.new(
        columnSpan: 5,
        columnStart: 1
      )
    )

    if entry.is_single_photo?
      document.components << AppleNews::Component::Body.new(
        format: 'html',
        text: exif(entry.photos.first),
        textStyle: AppleNews::Style::ComponentText.new(
          fontName: 'AvenirNext-Italic',
          textColor: '#666666',
          fontSize: 14,
          textAlignment: 'center'
        ),
        layout: AppleNews::ComponentLayout.new(
          columnSpan: 5,
          columnStart: 1
        )
      )
    end

    document.components << AppleNews::Component::Divider.new(
      stroke: AppleNews::Style::Stroke.new(color: '#FFFFFF00', width: 0),
      layout: AppleNews::ComponentLayout.new(
        margin: 36
      )
    )

    article = AppleNews::Article.new(nil, document: document)
    article.is_preview = true
    article
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
end
