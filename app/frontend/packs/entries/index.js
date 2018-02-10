import InfiniteScroll  from '../../modules/infinite_scroll.js';

new InfiniteScroll({
  containerSelector: '.entry-list',
  itemSelector: '.entry-list__item',
  paginationSelector: '.pagination',
  sentinelSelector: '.loading',
  footerSelector: '.footer',
  activeClass: 'loading--active'
});
