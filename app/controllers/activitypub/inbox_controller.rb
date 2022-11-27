class Activitypub::InboxController < ActivitypubController
  def index
    logger.info params
  end
end
