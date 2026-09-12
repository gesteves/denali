# Builds URLs for resized, cropped and reformatted versions of an image.
#
# The names here are deliberately generic — `width`, `contain`, `background`, `quality` — and
# describe what the caller wants rather than how it's delivered. Only #build_options knows the
# service, so swapping the image host means rewriting that one method and nothing else.
#
# Today that service is Cloudflare Images, addressed through this app's own images worker (see
# cloudflare/images), which resolves an ActiveStorage key against the R2 bucket — so the bucket's
# hostname never appears in a public URL. It used to be Thumbor, and for a while the module, its
# method and two of its options still carried Thumbor's names for options Cloudflare was serving.
module Transformable
  extend ActiveSupport::Concern

  # Formats that can be requested; `auto` negotiates avif/webp/jpeg from the request's Accept
  # header. PNG (used for favicons) isn't a valid value; omitting the format preserves the source
  # format, so PNG sources stay PNG.
  VALID_FORMATS = ['auto', 'jpeg', 'webp', 'avif']

  # Builds a URL for a transformed image, given its ActiveStorage key.
  #
  # @param image [String, nil] the ActiveStorage key.
  # @param opts [Hash] the transformations. :width, :height, :crop, :contain, :background,
  #   :quality, :grayscale, :format.
  # @return [String, nil] the URL, or nil without a key.
  def transformed_image_url(image, opts = {})
    return if image.blank?

    options = build_options(opts)
    path = options.present? ? "#{options.join(',')}/#{image}" : image

    "https://#{ENV['DOMAIN']}/images/#{path}"
  end

  private

  # Turns the generic options above into the query the image service understands.
  #
  # ⚠️ This is the only method that knows which service serves the image. Keep it that way.
  #
  # @param opts [Hash] the transformations.
  # @return [Array<String>] the service's options, in order.
  def build_options(opts)
    options = []
    options << "trim=#{crop_to_insets(opts[:crop])}" if opts[:crop].present?
    options << "width=#{opts[:width]}" if opts[:width].present?
    options << "height=#{opts[:height]}" if opts[:height].present? && opts[:crop].blank?
    # Fit the whole image inside the given box rather than filling it, padding the rest.
    options << 'fit=pad' if opts[:contain].present?
    options << "background=%23#{opts[:background]}" if opts[:background].present?
    options << "quality=#{opts[:quality]}" if opts[:quality].present?
    options << 'saturation=0' if opts[:grayscale].present?
    options << "format=#{opts[:format]}" if opts[:format].present? && VALID_FORMATS.include?(opts[:format])
    options
  end

  # Converts a `[left, top, right, bottom]` crop rectangle, in source pixels, into the number of
  # pixels to shave off each side, as `top;right;bottom;left`. The insets are applied before
  # resizing, so this reproduces a manual crop exactly. Crops are only ever passed by Photo
  # callers, so `width`/`height` are the photo's dimensions.
  #
  # @param crop [Array<Integer>] the crop rectangle.
  # @return [String] the per-side insets.
  def crop_to_insets(crop)
    left, top, right, bottom = crop
    [top, width - right, height - bottom, left].join(';')
  end
end
