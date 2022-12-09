class Activitypub::InboxesController < ActivitypubController
  skip_before_action :verify_authenticity_token
  skip_before_action :set_json_format

  def index
    @user = User.find(params[:user_id])

    @body = begin
      logger.tagged("Inbox") { logger.info request.raw_post }
      JSON.parse(request.raw_post)
    rescue
      nil
    end

    return head(:bad_request)          unless @body.present?
    return head(:unprocessable_entity) unless supported_activity_type?
    return head(:unauthorized)         unless authorized?

    render plain: 'OK'
  end

  private

  def supported_activity_type?
    ['Follow', 'Undo'].include? @body['type']
  end
  
  def authorized?
    date = Time.httpdate(request.headers['Date'])
    return false if date < 30.seconds.ago || date > 30.seconds.from_now

    signature_header = request.headers['signature']&.split(',')&.map do |pair|
      pair.split('=', 2).map do |value|
        value.gsub(/(^"|"$)/, '') # "foo" -> foo
      end
    end&.to_h

    key_id    = signature_header['keyId']
    headers   = signature_header['headers']
    signature = Base64.decode64(signature_header['signature'])

    actor = JSON.parse(HTTParty.get(key_id, headers: { 'Accept': 'application/activity+json' }).body)
    return false if actor['id'] != @body['actor']

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
    key.verify(OpenSSL::Digest::SHA256.new, signature, comparison_string)
  rescue
    false
  end
end
