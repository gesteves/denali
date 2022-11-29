class Activitypub::InboxController < ActivitypubController
  skip_before_action :verify_authenticity_token
  skip_before_action :set_json_format
  def index
    request.headers.each { |key,value|
      logger.info "#{key}='#{value}'" if key.start_with? "HTTP"
    }
    logger.info params
    render plain: 'OK'
  end
end
