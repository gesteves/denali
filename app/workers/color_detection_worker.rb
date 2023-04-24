require 'mini_magick'
class ColorDetectionWorker < ApplicationWorker
  def perform(photo_id)
    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.has_dimensions?

    is_bw = is_black_and_white?(photo)
    photo.black_and_white = is_bw
    photo.color = !is_bw
    photo.save
  end

  private

  def is_black_and_white?(photo)
    # Load the images with MiniMagick
    original_image = MiniMagick::Image.open(photo.url(width: 300))
    grayscaled_image = MiniMagick::Image.open(photo.url(width: 300, grayscale: true))
  
    # Calculate the mean error per pixel between the two images
    compare_result = original_image.compare(grayscaled_image, "mae")
    mean_error_per_pixel = compare_result[1].to_f
  
    # Get the threshold from the environment variable or use a default value of 5
    threshold = ENV.fetch('MAE_THRESHOLD', 5).to_f
  
    # Return true if the mean error per pixel is below the threshold
    mean_error_per_pixel <= threshold
  rescue StandardError => e
    false
  end
end
