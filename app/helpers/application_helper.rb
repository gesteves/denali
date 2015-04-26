module ApplicationHelper

  def responsive_image_tag(photo, widths = [], sizes = '', default_width = 1280, image_options = {}, html_options = {})
    image_options.reverse_merge! square: false, quality: 90
    html_options[:sizes] = sizes unless sizes == ''
    srcset = []
    if image_options[:square]
      widths.each do |w|
        srcset << "#{photo.url(w, w, image_options[:quality])} #{w}w"
      end
      html_options[:srcset] = srcset.join(', ')
      src = photo.url(default_width, default_width, image_options[:quality])
    else
      widths.each do |w|
        srcset << "#{photo.url(w, 0, image_options[:quality])} #{w}w"
      end
      html_options[:srcset] = srcset.join(', ')
      src = photo.url(default_width, 0, image_options[:quality])
    end
    image_tag src, html_options
  end
end
