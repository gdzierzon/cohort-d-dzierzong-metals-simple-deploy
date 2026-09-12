// Where the visitor actually came from, so a details page can offer "Back to
// Morgan Silver Dollar" instead of always pointing at the full list.
//
// Deliberately in-memory. A refresh or a pasted link starts with an empty trail
// and every details page falls back to its standing "All ..." link, which is why
// that link is always rendered - there has to be a route to the catalog even when
// there is no history to go back to.
//
// This is not the browser's history. history.back() would send a visitor who
// arrived by pasted URL out of the app entirely, and it cannot tell us the *name*
// of the page they came from - which is the whole point of the label.

const MAX_DEPTH = 10;

// Oldest first. The last entry is the page being looked at right now.
let trail = [];

const LIST_LABELS = new Map([
  ["/elements", "elements"],
  ["/alloys", "alloys"],
  ["/coins", "coins"],
]);

/**
 * Called by the router for every route it resolves, before the view renders.
 */
export function recordVisit(path) {
  const alreadyVisited = trail.findIndex((entry) => entry.path === path);
  if (alreadyVisited !== -1) {
    // Somewhere already on the trail: this is going back, not deeper. Dropping
    // everything after it keeps coin -> alloy -> coin from leaving the coin page
    // pointing "back" at the alloy it just came from, and stops a trail growing
    // forever around a loop.
    trail = trail.slice(0, alreadyVisited + 1);
    return;
  }

  trail.push({ path, label: null });
  if (trail.length > MAX_DEPTH) trail.shift();
}

/**
 * Give the current page a human name once its data has loaded. Until this is
 * called - or if the fetch fails - the previous-page link falls back to a label
 * derived from the path.
 */
export function labelCurrentVisit(label) {
  const current = trail[trail.length - 1];
  if (current && label) current.label = label;
}

/**
 * The page before this one, or null when there is nothing to go back to.
 */
export function previousVisit() {
  if (trail.length < 2) return null;
  const previous = trail[trail.length - 2];
  return { path: previous.path, label: previous.label ?? describePath(previous.path) };
}

export function resetHistory() {
  trail = [];
}

function describePath(path) {
  const known = LIST_LABELS.get(path);
  if (known) return known;

  // A details route we never got a name for, because it failed to load or was
  // left before its fetch finished.
  const segments = path.split("/").filter(Boolean);
  const last = segments[segments.length - 1];
  if (segments.length > 1 && /^\d+$/.test(last)) {
    return LIST_LABELS.has(`/${segments[0]}`) ? `that ${singular(segments[0])}` : "the previous page";
  }

  return segments.length ? segments.join(" ").replaceAll("-", " ") : "the previous page";
}

function singular(listSegment) {
  if (listSegment === "coins") return "piece";
  return listSegment.replace(/s$/, "");
}
