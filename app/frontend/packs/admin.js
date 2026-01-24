import { Application } from '@hotwired/stimulus';
import Rails from '@rails/ujs';
import Turbolinks from 'turbolinks';

// Admin controllers
import AltTextReviewController from '../controllers/admin/alt_text_review_controller';
import CharacterCounterController from '../controllers/admin/character_counter_controller';
import ClipboardController from '../controllers/admin/clipboard_controller';
import CropperController from '../controllers/admin/cropper_controller';
import DropdownController from '../controllers/admin/dropdown_controller';
import EntryFormController from '../controllers/admin/entry_form_controller';
import FocalPointController from '../controllers/admin/focal_point_controller';
import InstagramStoryPreviewController from '../controllers/admin/instagram_story_preview_controller';
import MapController from '../controllers/admin/map_controller';
import ModalController from '../controllers/admin/modal_controller';
import NavController from '../controllers/admin/nav_controller';
import NotificationsController from '../controllers/admin/notifications_controller';
import PhotoFormController from '../controllers/admin/photo_form_controller';
import QueueController from '../controllers/admin/queue_controller';
import RadioTabController from '../controllers/admin/radio_tab_controller';
import ShareFormController from '../controllers/admin/share_form_controller';
import SharingSettingsController from '../controllers/admin/sharing_settings_controller';
import SluggifierController from '../controllers/admin/sluggifier_controller';
import TagController from '../controllers/admin/tag_controller';
import TagAutocompleteController from '../controllers/admin/tag_autocomplete_controller';

// Shared controllers
import PlaceholderController from '../controllers/shared/placeholder_controller';

const application = Application.start();

// Register admin controllers
application.register('alt-text-review', AltTextReviewController);
application.register('character-counter', CharacterCounterController);
application.register('clipboard', ClipboardController);
application.register('cropper', CropperController);
application.register('dropdown', DropdownController);
application.register('entry-form', EntryFormController);
application.register('focal-point', FocalPointController);
application.register('instagram-story-preview', InstagramStoryPreviewController);
application.register('map', MapController);
application.register('modal', ModalController);
application.register('nav', NavController);
application.register('notifications', NotificationsController);
application.register('photo-form', PhotoFormController);
application.register('queue', QueueController);
application.register('radio-tab', RadioTabController);
application.register('share-form', ShareFormController);
application.register('sharing-settings', SharingSettingsController);
application.register('sluggifier', SluggifierController);
application.register('tag', TagController);
application.register('tag-autocomplete', TagAutocompleteController);

// Register shared controllers
application.register('placeholder', PlaceholderController);

Rails.start();
Turbolinks.start();
