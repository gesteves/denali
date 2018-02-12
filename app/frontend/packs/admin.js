import { Application } from 'stimulus';
import { definitionsFromContext } from 'stimulus/webpack-helpers';

const application = Application.start();
const context = require.context('controllers/admin', true, /.js$/);
application.load(definitionsFromContext(context));
