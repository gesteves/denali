class Activitypub::InboxController < ActivitypubController
  skip_before_action :verify_authenticity_token
  def index
    render plain: 'OK'
  end
end
