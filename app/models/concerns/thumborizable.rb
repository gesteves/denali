module Thumborizable
  extend ActiveSupport::Concern

  # Formats that can be requested via Cloudflare's `format` option; `auto`
  # negotiates avif/webp/jpeg from the request's Accept header. PNG (used for
  # favicons) isn't a valid URL API value; omitting `format` preserves the
  # source format, so PNG sources stay PNG.
  VALID_FORMATS = ['auto', 'jpeg', 'webp', 'avif']

  def thumbor_url(image, opts = {})
    return if image.blank?

    url = build_image_url(image)
    options = build_options(opts)
    return url if options.blank?

    "https://#{ENV['DOMAIN']}/cdn-cgi/image/#{options.join(',')}/#{url}"
  end

  private

  def build_image_url(image)
    image.start_with?('https://', 'http://') ? image : "https://#{ENV['IMAGES_ORIGIN_HOST']}/#{image}"
  end

  def build_options(opts)
    options = []
    options << "trim=#{crop_to_trim(opts[:crop])}" if opts[:crop].present?
    options << "width=#{opts[:width]}" if opts[:width].present?
    options << "height=#{opts[:height]}" if opts[:height].present? && opts[:crop].blank?
    options << 'fit=pad' if opts[:fit_in].present?
    options << "background=%23#{opts[:fill]}" if opts[:fill].present?
    options << "quality=#{opts[:quality]}" if opts[:quality].present?
    options << 'saturation=0' if opts[:grayscale].present?
    options << "format=#{opts[:format]}" if opts[:format].present? && VALID_FORMATS.include?(opts[:format])
    options
  end

  # Converts a `[left, top, right, bottom]` crop rectangle (in source pixels)
  # into Cloudflare's `trim=top;right;bottom;left` option, where each value is
  # the number of pixels to shave off that side. Trim is applied before
  # resizing, so this reproduces Thumbor's manual crop exactly. Crops are only
  # ever passed by Photo callers, so `width`/`height` are the photo's
  # dimensions.
  def crop_to_trim(crop)
    left, top, right, bottom = crop
    [top, width - right, height - bottom, left].join(';')
  end
end
