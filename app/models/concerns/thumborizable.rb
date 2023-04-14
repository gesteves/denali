module Thumborizable
  extend ActiveSupport::Concern

  VALID_FORMATS = ['jpeg', 'webp', 'avif', 'png', 'gif']

  def thumbor_url(image, opts = {})
    return if image.blank?

    url = image.start_with?('https://', 'http://') ? image : "#{ENV['S3_BUCKET']}/#{image}"

    filters = []
    filters << "fill(#{opts[:fill]},true)" if opts[:fill].present?
    filters << "quality(#{opts[:quality]})" if opts[:quality].present?
    filters << "format(#{opts[:format]})" if opts[:format].present? && VALID_FORMATS.include?(opts[:format])

    params = {
      image: url,
      width: opts[:width],
      crop: opts[:crop],
      fit_in: opts[:fit_in]
    }.compact

    params[:height] = opts[:height] unless opts[:crop].present?
    params[:filters] = filters if filters.present?

    path = Thumb.generate(params)
    thumbor_path = ENV['THUMBOR_PATH'].presence ? "/#{ENV['THUMBOR_PATH']}" : ''
    "https://#{ENV['THUMBOR_DOMAIN']}#{thumbor_path}#{path}"
  end
end
