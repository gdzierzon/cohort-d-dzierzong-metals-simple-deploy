import { previousVisit } from "../../navigation-history.js";

// The two links at the top of every details page.
//
//   * "Back to ..." follows the route the visitor actually took, so arriving at an
//     alloy from a coin offers the coin back - not the alloy list they never saw.
//   * "All ..." is always there, because the back link is not guaranteed to be:
//     on a refresh, or a link someone pasted, there is no trail at all.
//
// When the previous page IS the list, the two would say the same thing, so only
// one link is rendered.

/**
 * @param {string} listPath  e.g. "/alloys" - where "All ..." points.
 * @param {string} listLabel e.g. "alloys" - used in both link texts.
 */
export function detailsNavMarkup(listPath, listLabel) {
  const previous = previousVisit();
  const allLink = `<a class="details-all" href="#${listPath}">All ${escapeHtml(listLabel)}</a>`;

  if (!previous) {
    return `<nav class="details-nav" aria-label="Catalog navigation">${allLink}</nav>`;
  }

  const backLink =
    `<a class="details-back" href="#${escapeHtml(previous.path)}">` +
    `‹ Back to ${escapeHtml(previous.label)}</a>`;

  if (previous.path === listPath) {
    return `<nav class="details-nav" aria-label="Catalog navigation">${backLink}</nav>`;
  }

  return `<nav class="details-nav" aria-label="Catalog navigation">${backLink}${allLink}</nav>`;
}

// Labels come from the catalog data, so they are someone else's text by the time
// an admin can edit a name. Everything here is interpolated into markup, so it
// gets escaped.
function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
