module Thumborizable
  extend ActiveSupport::Concern

  VALID_FORMATS = ['jpeg', 'webp', 'avif', 'png', 'gif']

  def thumbor_url(key, opts = {})
    return if key.blank?

    filters = []
    filters << "fill(#{opts[:fill]})" if opts[:fill].present?
    filters << "format(#{opts[:format]})" if opts[:format].present? && VALID_FORMATS.include?(opts[:format])

    params = {
      image: "#{ENV['S3_BUCKET']}/#{key}",
      width: opts[:width],
      crop: opts[:crop],
      fit_in: opts[:fit_in]
    }.compact

    params[:height] = opts[:height] unless opts[:crop].present?
    params[:filters] = filters if filters.present?

    path = Thumbor.generate(params)
    "https://#{ENV['THUMBOR_DOMAIN']}/thumbor#{path}"
  end
end
