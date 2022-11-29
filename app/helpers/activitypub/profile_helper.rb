module Activitypub::ProfileHelper
  def activitypub_profile_context
    ["https://www.w3.org/ns/activitystreams",
     "https://w3id.org/security/v1",
     {
      manuallyApprovesFollowers: "as:manuallyApprovesFollowers",
			toot: "http://joinmastodon.org/ns#",
      discoverable: "toot:discoverable",
      blurhash: "toot:blurhash",
      schema: "http://schema.org#",
			PropertyValue: "schema:PropertyValue",
			value: "schema:value",
      focalPoint: {
        '@container': "@list",
        '@id': "toot:focalPoint"
      },
     }
    ]
  end

  def attachments
    attachments = []
    if @user.profile.website.present?
      attachments << {
        type: "PropertyValue",
        name: "Web",
        value: attachment_link(@user.profile.website)
      }
    end
    if @user.profile.flickr.present?
      attachments << {
        type: "PropertyValue",
        name: "Flickr",
        value: attachment_link(@user.profile.flickr)
      }
    end
    if @user.profile.instagram.present?
      attachments << {
        type: "PropertyValue",
        name: "Instagram",
        value: attachment_link(@user.profile.instagram)
      }
    end
    if @user.profile.tumblr.present?
      attachments << {
        type: "PropertyValue",
        name: "Tumblr",
        value: attachment_link(@user.profile.tumblr)
      }
    end
    attachments.sort { |a, b| a[:name] <=> b[:name] }
  end

  def attachment_link(url)
    link_to url.gsub(/(^https?:\/\/(www\.)?)|\/$/, ''), url
  end
end
