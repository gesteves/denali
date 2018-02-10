import ImageZoom from '../../modules/image_zoom.js';
import LazyLoad  from '../../modules/lazy_load.js';

new ImageZoom({
  imagesSelector: '.entry__photo',
  zoomClass: 'entry__photo-container--zoom',
  zoomableClass: 'entry__photo--zoomable',
  maxImageWidth: 1680
});

new LazyLoad('js-lazy-load');
