class WellKnown::NodeinfoController < ApplicationController
  before_action :set_json_format
  before_action :set_max_age

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

  private
  def set_json_format
    request.format = 'json'
  end
end
