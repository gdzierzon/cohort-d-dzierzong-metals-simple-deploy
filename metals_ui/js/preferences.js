// Remembers catalog filter and sort choices so leaving a page and coming back
// does not mean re-picking everything.
//
// localStorage, not the URL: the router matches on the whole hash, so
// "#/elements?sort=name" would fall through to not-found. It is also per-viewer
// and per-browser by nature, which is the right scope for a display preference.
//
// Every read and write is wrapped: localStorage throws outright in some
// contexts (Safari private mode, browsers set to block site data), and a
// remembered filter is never worth breaking a page over.

// Bumping the version retires saved values whose shape no longer applies,
// rather than trying to migrate them.
const STORAGE_VERSION = "v1";
const keyFor = (name) => `metals-atlas:${name}:${STORAGE_VERSION}`;

export function loadPreferences(name) {
  try {
    const stored = window.localStorage.getItem(keyFor(name));
    if (!stored) return {};

    const parsed = JSON.parse(stored);
    // Anything but a plain object means the entry was hand-edited or written by
    // another version; treat it as absent rather than trusting it.
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}

export function savePreferences(name, preferences) {
  try {
    window.localStorage.setItem(keyFor(name), JSON.stringify(preferences));
  } catch {
    // Storage unavailable or full. The page keeps working; the choice just
    // will not outlive this visit.
  }
}

/**
 * Restores a remembered set of checkbox codes.
 *
 * Returns the stored codes when they are usable, and `null` to mean "keep the
 * markup defaults". A stored list that no longer overlaps the available codes
 * would leave every box unchecked and an empty page that looks broken, so it
 * is rejected - but a deliberate empty selection is preserved, because the
 * reader chose that.
 */
export function restoreCodes(stored, available) {
  if (!Array.isArray(stored)) return null;
  if (stored.length === 0) return [];

  const usable = stored.filter((code) => available.includes(code));
  return usable.length ? usable : null;
}
