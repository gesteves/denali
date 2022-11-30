class Activitypub::InboxController < ActivitypubController
  skip_before_action :verify_authenticity_token
  skip_before_action :set_json_format

  def index
    @user = User.find(params[:user_id])
    logger.info params

    signature_header = request.headers['signature']&.split(',')&.map do |pair|
      pair.split('=',2).map do |value|
        value.gsub(/(^"|"$)/, '') # "foo" -> foo
      end
    end&.to_h

    if signature_header.blank?
      render plain: 'Bad request', status: 400
      return
    end

    key_id    = signature_header['keyId']
    headers   = signature_header['headers']
    signature = Base64.decode64(signature_header['signature'])

    begin
      actor = JSON.parse(HTTParty.get(key_id, headers: { 'Accept': 'application/activity+json' }).body)
      key   = OpenSSL::PKey::RSA.new(actor['publicKey']['publicKeyPem'])
    rescue
      render plain: 'Bad request', status: 400
      return
    end

    comparison_string = headers.split(' ').map do |signed_header_name|
      if signed_header_name == '(request-target)'
        "(request-target): post #{request.path}"
      elsif signed_header_name == 'host'
        "host: #{ENV['DOMAIN']}"
      else
        "#{signed_header_name}: #{request.headers[signed_header_name.capitalize]}"
      end
    end.join("\n")

    if key.verify(OpenSSL::Digest::SHA256.new, signature, comparison_string)
      render plain: 'OK'
    else
      render plain: 'Unauthorized', status: 401
    end
  end
end
