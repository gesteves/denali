class ImaginaryUrl
  @@presigner = Aws::S3::Presigner.new
  def self.generate(opts = {})
    opts[:url] = @@presigner.presigned_url(:get_object, bucket: ENV['s3_bucket'], key: opts[:image], expires_in: 604800)
    opts[:url] = ERB::Util.url_encode(opts[:url])
    opts.delete(:image)

    sign_key = ENV['IMAGINARY_SIGNATURE_KEY']
    if opts[:w]
      opts[:width] = opts.delete(:w).to_i
    end
    if opts[:h]
      opts[:height] = opts.delete(:h).to_i
    end

    # TODO: currently don't support smart crops, which are used by social metatags
    # Example: {"smart":true,"url":signed_img_urk,"width":944,"height":944}
    # Rails.logger.info("imaginary_opts - #{opts.to_json}")

    url_path = "/resize"
    url_query = opts.stringify_keys.sort.map do |param_name, param_value|
      "#{param_name}=#{param_value}"
    end.join("&")
    sign = Base64.urlsafe_encode64(
      OpenSSL::HMAC.digest("SHA256", sign_key, url_path + url_query)
    ).sub(/=$/, '')
    url_query += "&sign=#{sign}"

    uri = URI.parse('https://imaginary.hikerilluminati.com/')
    uri.path = url_path
    uri.query = url_query
    uri.to_s
  end
end
