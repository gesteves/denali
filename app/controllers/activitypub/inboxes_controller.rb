class Activitypub::InboxesController < ActivitypubController
  skip_before_action :verify_authenticity_token
  skip_before_action :set_json_format

  def index
    @user = User.find(params[:user_id])

    @body = begin
      logger.tagged("Inbox") do
        logger.info request.raw_post
      end
      JSON.parse(request.raw_post)
    rescue
      nil
    end

    if @body.blank? || !is_valid_request?
      render plain: 'Bad request', status: 400 and return
    end

    if !supported_action?
      render plain: 'Accepted', status: 202 and return
    end

    render plain: 'OK'
  end

  private
  def supported_action?
    ['Follow', 'Undo'].include? @body['type']
  end
  
  def is_valid_request?
    date = Time.httpdate(request.headers['Date'])
    raise Activitypub::Inbox::InvalidDateError if date < 30.seconds.ago || date > 30.seconds.from_now

    signature_header = request.headers['signature']&.split(',')&.map do |pair|
      pair.split('=',2).map do |value|
        value.gsub(/(^"|"$)/, '') # "foo" -> foo
      end
    end&.to_h

    key_id    = signature_header['keyId']
    headers   = signature_header['headers']
    signature = Base64.decode64(signature_header['signature'])

    actor = JSON.parse(HTTParty.get(key_id, headers: { 'Accept': 'application/activity+json' }).body)
    raise Activitypub::Inbox::InvalidActorError if actor['id'] != @body['actor']

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

    key = OpenSSL::PKey::RSA.new(actor['publicKey']['publicKeyPem'])
    valid_signature = key.verify(OpenSSL::Digest::SHA256.new, signature, comparison_string)
    raise Activitypub::Inbox::InvalidSignatureError if !valid_signature
    valid_signature
  rescue => e
    logger.tagged("Inbox") do
      logger.error e
    end
    false
  end
end
