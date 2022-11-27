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
end
