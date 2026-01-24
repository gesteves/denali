import { Application } from '@hotwired/stimulus';

// Application controllers
import GridController from '../controllers/application/grid_controller';
import InfiniteScrollController from '../controllers/application/infinite_scroll_controller';
import PageController from '../controllers/application/page_controller';
import PaginationController from '../controllers/application/pagination_controller';
import PhotoController from '../controllers/application/photo_controller';
import PushNotificationsController from '../controllers/application/push_notifications_controller';

// Shared controllers
import PlaceholderController from '../controllers/shared/placeholder_controller';

const application = Application.start();

// Register application controllers
application.register('grid', GridController);
application.register('infinite-scroll', InfiniteScrollController);
application.register('page', PageController);
application.register('pagination', PaginationController);
application.register('photo', PhotoController);
application.register('push-notifications', PushNotificationsController);

// Register shared controllers
application.register('placeholder', PlaceholderController);

if (navigator.serviceWorker) {
  navigator.serviceWorker.register('/service_worker.js', {
    scope: '/',
    updateViaCache: 'none'
  });
}
