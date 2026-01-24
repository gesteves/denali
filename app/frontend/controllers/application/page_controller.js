import { trackPageView } from '../../lib/analytics';
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  connect() {
    trackPageView();
  }
}
