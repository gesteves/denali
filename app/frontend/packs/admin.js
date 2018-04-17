/* global require */
import { Application } from 'stimulus';
import { definitionsFromContext } from 'stimulus/webpack-helpers';
import Rails from 'rails-ujs';
import Turbolinks from 'turbolinks';

const application = Application.start();
const context = require.context('controllers/admin', true, /.js$/);
application.load(definitionsFromContext(context));
Rails.start();
Turbolinks.start();
