class Activitypub::InboxController < ActivitypubController
  def index
    logger.info params
    render text: 'OK'
  end
end
