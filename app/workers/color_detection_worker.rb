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
  
    # Calculate the mean error per pixel between the two images using the compare tool
    compare_tool = MiniMagick::Tool::Compare.new
    compare_tool.metric('mae')
    compare_tool << original_image.path
    compare_tool << grayscaled_image.path
    compare_tool << 'null:'
    compare_output, _ = compare_tool.call
  
    # Extract the mean absolute error from the output
    mean_error_per_pixel = compare_output.split(' ')[1].to_f
  
    # Get the threshold from the environment variable or use a default value of 5
    threshold = ENV.fetch('MAE_THRESHOLD', 5).to_f
  
    # Return true if the mean error per pixel is below the threshold
    mean_error_per_pixel <= threshold
  rescue StandardError => e
    false
  end
end
