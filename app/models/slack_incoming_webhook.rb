class SlackIncomingWebhook < ApplicationRecord
  belongs_to :blog, touch: true

  def self.post_all(entry)
    self.find_each do |webhook|
      SlackJob.perform_later(entry, webhook)
    end
  end
end
