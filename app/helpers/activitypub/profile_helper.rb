module Activitypub::ProfileHelper
  def json_context
    ["https://www.w3.org/ns/activitystreams",
     "https://w3id.org/security/v1",
     {
      manuallyApprovesFollowers: "as:manuallyApprovesFollowers",
			toot: "http://joinmastodon.org/ns#",
      discoverable: "toot:discoverable",
      schema: "http://schema.org#",
			PropertyValue: "schema:PropertyValue",
			value: "schema:value"
     }
    ]
  end

  def attachments
    attachments = []
    if @profile.website.present?
      attachments << {
        type: "PropertyValue",
        name: "Website",
        value: attachment_link(@profile.website)
      }
    end
    if @profile.flickr.present?
      attachments << {
        type: "PropertyValue",
        name: "Flickr",
        value: attachment_link(@profile.flickr)
      }
    end
    if @profile.instagram.present?
      attachments << {
        type: "PropertyValue",
        name: "Instagram",
        value: attachment_link(@profile.instagram)
      }
    end
    if @profile.tumblr.present?
      attachments << {
        type: "PropertyValue",
        name: "Tumblr",
        value: attachment_link(@profile.tumblr)
      }
    end
    attachments.sort { |a, b| a[:name] <=> b[:name] }
  end

  def attachment_link(url)
    link_to url.gsub(/(^https?:\/\/(www\.)?)|\/$/, ''), url
  end
end
