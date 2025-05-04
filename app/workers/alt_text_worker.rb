class AltTextWorker < ApplicationWorker
  def perform(photo_id)
    photo = Photo.find(photo_id)
    return if ENV['OPENAI_API_KEY'].blank?
    raise UnprocessedPhotoError unless photo.has_dimensions?

    body = {
      model: 'gpt-4.1',
      store: false,
      instructions: instructions,
      user: photo.entry.user.id.to_s,
      input: [
        {
          role: 'user',
          content: [
            {
              type: "input_image",
              image_url: photo.chatgpt_url
            }
          ]
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "alt_text",
          schema: {
            type: "object",
            properties: {
              "altText": {
                type: "string"
              }
            },
            required: ["altText"],
            additionalProperties: false,
          },
        }
      }
    }

    response = Chatgpt.new.create_response(body)
    json = JSON.parse(response['output']&.select { |o| o['role'] == 'assistant' }&.first&.dig('content')&.first&.dig('text'), symbolize_names: true)
    alt_text = json[:altText]
    raise if alt_text.blank?
    photo.alt_text = alt_text
    photo.auto_generated_alt_text = true
    photo.save!
  end

  private

  def instructions
    <<~PROMPT
      **Context**:
      Social media networks and blog posts require images to have alt text for accessibility reasons. It's sometimes hard for humans to find the right words to describe them accurately for people with limited vision. Your job is to receive an image and write a short alt text that describes its contents objectively.

      **Instructions**:
      - Receive the image and write a short alt text that describes its contents.
      - Keep the description factual and objective. Omit subjective details such as the mood of the image.
      - Start with a very short summary of the whole image in one sentence. Then, provide a detailed description of its contents. That way, a person using a screen reader can move on if the summary is enough, or let their screen reader read the more detailed description.
      - Do not specify if the image is in color or black and white.
      - When quoting text present within the image, you **must** use double quotes (" ") and use sentence casing.
      - Do not output any text except the alt text itself, so the user can simply copy and paste the entire output elsewhere.
      - The alt text must be less than 1,000 characters.
    PROMPT
  end
end
