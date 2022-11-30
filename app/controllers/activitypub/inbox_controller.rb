class Activitypub::InboxController < ActivitypubController
  skip_before_action :verify_authenticity_token
  skip_before_action :set_json_format

  def index
    logger.info request.headers['signature']
    logger.info params[:inbox]
    render plain: 'OK'
  end
end
