module Thumborizable
  extend ActiveSupport::Concern

  VALID_FORMATS = ['jpeg', 'webp', 'avif', 'png', 'gif']

  def thumbor_url(image, opts = {})
    return if image.blank?

    url = build_image_url(image)
    filters = build_filters(opts)
    params = build_params(url, filters, opts)

    generate_thumbor_url(params)
  end

  private

  def build_image_url(image)
    image.start_with?('https://', 'http://') ? image : "#{ENV['S3_BUCKET']}/#{image}"
  end

  def build_filters(opts)
    filters = []
    filters << "fill(#{opts[:fill]},true)" if opts[:fill].present?
    filters << "quality(#{opts[:quality]})" if opts[:quality].present?
    filters << "grayscale()" if opts[:grayscale].present?
    filters << "format(#{opts[:format]})" if opts[:format].present? && VALID_FORMATS.include?(opts[:format])
    filters
  end

  def build_params(url, filters, opts)
    params = {
      image: url,
      width: opts[:width],
      crop: opts[:crop],
      fit_in: opts[:fit_in]
    }.compact

    params[:height] = opts[:height] unless opts[:crop].present?
    params[:filters] = filters if filters.present?
    params
  end

  def generate_thumbor_url(params)
    thumbor = Thumbor::CryptoURL.new(ENV['THUMBOR_SECURITY_KEY'])
    path = thumbor.generate(params)
    thumbor_path = ENV['THUMBOR_PATH'].presence ? "/#{ENV['THUMBOR_PATH']}" : ''
    "https://#{ENV['THUMBOR_DOMAIN']}#{thumbor_path}#{path}"
  end
end
