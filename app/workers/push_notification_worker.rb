class PushNotificationWorker < ApplicationWorker
  def perform(push_subscription_id, entry_id)
    push_subscription = PushSubscription.find(push_subscription_id)
    entry = Entry.published.find(entry_id)

    return if push_subscription.blank? || entry.blank?

    vapid_keys = {
      subject: "mailto:#{mailto_address}",
      public_key: ENV['VAPID_PUBLIC_KEY'],
      private_key: ENV['VAPID_PRIVATE_KEY']
    }

    message = {
      title: entry.blog.name,
      body: entry.plain_title,
      icon: entry.blog.touch_icon_url(width: 512),
      image: entry.photos.first.url(width: 1920),
      url: entry.permalink_url
    }

    begin
      WebPush.payload_send(
        message: JSON.generate(message),
        endpoint: push_subscription.endpoint,
        p256dh: push_subscription.p256dh,
        auth: push_subscription.auth,
        vapid: vapid_keys,
        ttl: 180
      )
    rescue WebPush::InvalidSubscription, WebPush::ExpiredSubscription => e
      push_subscription.destroy
    end
  end

  private
  def mailto_address
    ENV['VAPID_MAILTO_ADDRESS']
  end
end
