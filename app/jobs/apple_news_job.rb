class AppleNewsJob < ApplicationJob

  def perform(entry)
    if Rails.env.production?
      return if !entry.is_published? || ENV['apple_news_channel_id'].blank? || ENV['apple_news_key_id'].blank? || ENV['apple_news_secret'].blank?

      document = entry.to_apple_news_document

      article = begin
        AppleNews::Article.new(entry.apple_news_id, document: document)
      rescue NoMethodError
        # This means an article with that apple_news_id doesn't exist,
        # (likely deleted in News Publisher), so just create a new article.
        AppleNews::Article.new
      end

      response = article.save!
      if response.is_a? Array
        raise response
      elsif article.id.present? && article.id != entry.apple_news_id
        entry.apple_news_id = article.id
        entry.save
      end
    elsif Rails.env.development?
      # In dev mode, instead of pushing to Apple News, generate the article.json
      # and store locally for testing with News Preview app: https://developer.apple.com/news-preview/
      File.open('tmp/article.json', 'w'){ |f| f << entry.to_apple_news_document.as_json.to_json }
    end
  end
end
