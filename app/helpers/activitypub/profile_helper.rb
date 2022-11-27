module Activitypub::ProfileHelper
  def json_context
    ["https://www.w3.org/ns/activitystreams",
     "https://w3id.org/security/v1",
     {
      manuallyApprovesFollowers: "as:manuallyApprovesFollowers",
			toot: "http://joinmastodon.org/ns#",
      discoverable: "toot:discoverable"
     }
    ]
  end

  def attachments
    attachments = []
    if @profile.website.present?
      attachments << {
        type: "PropertyValue",
        name: "Website",
        value: @profile.website
      }
    end
    if @profile.flickr.present?
      attachments << {
        type: "PropertyValue",
        name: "Flickr",
        value: @profile.flickr
      }
    end
    if @profile.instagram.present?
      attachments << {
        type: "PropertyValue",
        name: "Instagram",
        value: @profile.instagram
      }
    end
    if @profile.tumblr.present?
      attachments << {
        type: "PropertyValue",
        name: "Tumblr",
        value: @profile.tumblr
      }
    end
    attachments.sort { |a, b| a[:name] <=> b[:name] }
  end
end
