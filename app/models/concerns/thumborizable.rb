module Thumborizable
  extend ActiveSupport::Concern

  # Formats that can be requested via Cloudflare's `format` option; `auto`
  # negotiates avif/webp/jpeg from the request's Accept header. PNG (used for
  # favicons) isn't a valid URL API value; omitting `format` preserves the
  # source format, so PNG sources stay PNG.
  VALID_FORMATS = ['auto', 'jpeg', 'webp', 'avif']

  # Builds a URL for an image, given its ActiveStorage key. These are served by
  # the images worker (see cloudflare/images), which resolves the key against
  # the R2 bucket — so the bucket's hostname never appears in a public URL.
  def thumbor_url(image, opts = {})
    return if image.blank?

    options = build_options(opts)
    path = options.present? ? "#{options.join(',')}/#{image}" : image

    "https://#{ENV['DOMAIN']}/images/#{path}"
  end

  private

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
