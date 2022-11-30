class Activitypub::InboxController < ActivitypubController
  skip_before_action :verify_authenticity_token
  skip_before_action :set_json_format

  helper_method :is_valid_signature?, :is_valid_date?, :is_valid_digest?

  def index
    @user = User.find(params[:user_id])
    logger.info request.raw_post
    body = JSON.parse(request.raw_post)

    if is_valid_date? && is_valid_signature?
      render plain: 'OK'
    else
      render plain: 'Unauthorized', status: 401
    end
  end

  private

  def is_valid_date?
    Time.httpdate(request.headers['Date']) >= 30.seconds.ago
  rescue
    false
  end

  def is_valid_signature?
    signature_header = request.headers['signature']&.split(',')&.map do |pair|
      pair.split('=',2).map do |value|
        value.gsub(/(^"|"$)/, '') # "foo" -> foo
      end
    end&.to_h

    key_id    = signature_header['keyId']
    headers   = signature_header['headers']
    signature = Base64.decode64(signature_header['signature'])

    actor = JSON.parse(HTTParty.get(key_id, headers: { 'Accept': 'application/activity+json' }).body)
    key   = OpenSSL::PKey::RSA.new(actor['publicKey']['publicKeyPem'])

    comparison_string = headers.split(' ').map do |signed_header_name|
      if signed_header_name == '(request-target)'
        "(request-target): post #{request.path}"
      elsif signed_header_name == 'host'
        "host: #{ENV['DOMAIN']}"
      elsif signed_header_name == 'digest'
        "digest: SHA-256=#{Digest::SHA256.base64digest(request.raw_post)}"
      else
        "#{signed_header_name}: #{request.headers[signed_header_name.capitalize]}"
      end
    end.join("\n")

    key.verify(OpenSSL::Digest::SHA256.new, signature, comparison_string)
  rescue
    false
  end
end
