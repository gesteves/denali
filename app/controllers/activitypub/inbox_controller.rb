class Activitypub::InboxController < ActivitypubController
  skip_before_action :verify_authenticity_token
  def index
    logger.info params
    render plain: 'OK'
  end
end
