module Types
  class ShareOnBlueskyInput < Types::BaseInputObject
    argument :url, String, required: true
  end
end
