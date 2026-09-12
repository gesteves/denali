# Serves the standard.site verification endpoint.
#
# A reader that finds a site.standard.publication record checks it against the site it claims by
# fetching this path and comparing the at:// URI. The matching <link rel> tags are in the page head.
class StandardSiteController < ApplicationController
  def show
    uri = @photoblog&.standard_site_publication_uri

    if uri.blank?
      head :not_found
    else
      render plain: uri, content_type: 'text/plain'
    end
  end
end
