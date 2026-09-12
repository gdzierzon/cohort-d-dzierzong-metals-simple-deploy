import { isAdmin, isAuthenticated, state } from "../state.js";

export function navigation() {
  const accountLinks = isAuthenticated()
    ? `<span>Signed in as ${state.currentUser.username}</span><a href="#/logout">Log out</a>`
    : `<a class="button" href="#/login">Log in</a>`;
  const adminLink = isAdmin() ? `<a href="#/admin">Administration</a>` : "";
  const catalogLinks = `<a href="#/elements">Elements</a><a href="#/alloys">Alloys</a><a href="#/coins">Coins &amp; Bullion</a>`;

  return `
    <header class="site-header">
      <div class="site-header__inner">
        <a class="brand" href="#/">Metals Atlas</a>
        <nav class="navigation" aria-label="Main navigation">
          ${catalogLinks}${adminLink}${accountLinks}
        </nav>
      </div>
    </header>
  `;
}
