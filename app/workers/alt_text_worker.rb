class AltTextWorker < ApplicationWorker
  def perform(photo_id)
    photo = Photo.find(photo_id)
    return if ENV['ANTHROPIC_API_KEY'].blank?
    raise UnprocessedPhotoError unless photo.has_dimensions?

    body = {
      model: 'claude-sonnet-4-5',
      max_tokens: 1024,
      system: instructions,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: "image",
              source: {
                type: "url",
                url: photo.claude_url
              }
            },
            {
              type: "text",
              text: "Write an alt text for this image."
            }
          ]
        }
      ]
    }

    response = Claude.new.create_message(body)
    alt_text = response.dig('content', 0, 'text')&.strip
    raise if alt_text.blank?
    photo.auto_generated_alt_text = alt_text
    photo.alt_text_needs_review = true
    photo.save!
  end

  private

  def instructions
    <<~PROMPT
      You are an expert at writing alt text for images for accessibility purposes. Your job is to receive an image and write a short alt text that describes its contents objectively.

      <instructions>
        - Keep the description factual and objective. Omit subjective details such as the mood of the image.
        - Use present participles (verbs ending in -ing) without auxiliary verbs rather than present tense verbs when describing actions (for example, "a dog running on the beach," not "a dog runs on the beach" or "a dog is running on the beach").
        - Do not specify if the image is in color or black and white.
        - Follow Chicago Manual of Style 18 conventions.
        - The alt text must be less than 1,000 characters.
        - Output ONLY the alt text itself with no preamble, explanation, or additional text. The user should be able to copy and paste your entire response directly as the alt text.
      </instructions>
    PROMPT
  end
end
