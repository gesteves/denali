/* global require */
import { Application } from 'stimulus';
import { definitionsFromContext } from 'stimulus/webpack-helpers';

const application = Application.start();
const context = require.context('controllers/application', true, /.js$/);
const sharedContext = require.context('controllers/shared', true, /.js$/);
application.load(definitionsFromContext(context));
application.load(definitionsFromContext(sharedContext));

if (navigator.serviceWorker) {
  navigator.serviceWorker.register('/service_worker.js', {
    scope: '/',
    updateViaCache: 'none'
  });
}
