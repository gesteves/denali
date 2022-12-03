class WellKnown::NodeinfoController < ApplicationController
  def index
    render json: {
      links: [
        {
          rel: 'http://nodeinfo.diaspora.software/ns/schema/2.0',
          href: nodeinfo_url
        }
      ]
    }
  end

  def show
    @users = User.all.count
    @entries = Entry.published.count
  end
end
