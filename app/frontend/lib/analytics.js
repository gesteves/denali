/* global clicky */

/**
 * Tracks an event in Clicky
 * @param {string} href The url or path for the event to be tracked.
 * @param {string} label The label for the event to be tracked.
 * @param {string} type The type of event to be tracked.
 */
export function trackClickyEvent (href, label, type) {
  if (typeof clicky !== 'undefined') {
    clicky.log(href, label, type);
  }
}

/**
 * Tracks a goal in Clicky
 * @param {string} label The label for the goal to be tracked.
 */
export function trackClickyGoal (label) {
  if (typeof clicky !== 'undefined') {
    clicky.goal(label);
  }
}
