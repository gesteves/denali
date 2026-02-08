import { trackPageView } from '../lib/analytics';

let _observer;

/**
 * Controls updating the browser bar while scrolling through a list of entries.
 */
export default class Pagination {
  static observe (element) {
    if (!('IntersectionObserver' in window)) {
      return;
    }
    observer().observe(element);
  }

  static unobserve (element) {
    if (!('IntersectionObserver' in window)) {
      return;
    }
    observer().unobserve(element);
  }
}

/**
 * Return or instantiate an IntersectionObserver to use in the static function.
 * @return {IntersectionObserver} An intersection observer.
 */
function observer () {
  if (!_observer) {
    _observer = new IntersectionObserver(handleIntersection, { threshold: 1.0 });
  }
  return _observer;
}

/**
  * As each element is in view, this function uses the `page-url` data attribute to
  * update the URL in the browser address bar using the History API, and
  * tracks the page view in Analytics if the page changes.
  * @param {IntersectionObserverEntry[]} entries An array of intersection observer entries
  */
function handleIntersection (entries) {
  const entry = entries.find(e => e.intersectionRatio > 0 || e.isIntersecting);
  if (!entry) {
    return;
  }
  const previousPath = window.location.pathname;
  window.history.replaceState(null, null, entry.target.getAttribute('data-pagination-page-url'));
  if (previousPath !== window.location.pathname) {
    trackPageView();
  }
}
