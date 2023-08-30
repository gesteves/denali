import { trackPageView } from '../../lib/analytics';
import { Controller } from "stimulus";

export default class extends Controller {
  connect() {
    trackPageView();
  }
}
