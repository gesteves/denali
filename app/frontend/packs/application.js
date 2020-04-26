/* global require */
import { Application } from 'stimulus';
import { definitionsFromContext } from 'stimulus/webpack-helpers';

const application = Application.start();
const context = require.context('controllers/application', true, /.js$/);
application.load(definitionsFromContext(context));

if (navigator.serviceWorker) {
  navigator.serviceWorker.register('/service_worker.js', {
    scope: '/',
    updateViaCache: 'none'
  });
}
