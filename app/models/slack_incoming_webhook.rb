class SlackIncomingWebhook < ActiveRecord::Base
  belongs_to :blog

  def self.post_all(entry)
    self.find_each do |webhook|
      SlackJob.perform_later(entry, webhook)
    end
  end
end
