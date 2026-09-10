import { clearSession, restoreSession } from "./auth/session.js";
import { requireAdmin, requireLogin } from "./auth/guards.js";
import { navigation } from "./components/navigation.js";
import { registerRoute, startRouter } from "./router.js";
import { adminHomeView } from "./views/admin/admin-home-view.js";
import { alloysAdminView, bindAlloysAdminView } from "./views/admin/alloys-admin-view.js";
import { bindCoinsAdminView, coinsAdminView } from "./views/admin/coins-admin-view.js";
import { bindElementsAdminView, elementsAdminView } from "./views/admin/elements-admin-view.js";
import { bindUsersAdminView, usersAdminView } from "./views/admin/users-admin-view.js";
import { bindAlloysView, alloysView } from "./views/catalog/alloys-view.js";
import { alloyDetailsView, bindAlloyDetailsView } from "./views/catalog/alloy-details-view.js";
import { bindCoinsView, coinsView } from "./views/catalog/coins-view.js";
import { bindCoinDetailsView, coinDetailsView } from "./views/catalog/coin-details-view.js";
import { bindElementsView, elementsView } from "./views/catalog/elements-view.js";
import { bindElementDetailsView, elementDetailsView } from "./views/catalog/element-details-view.js";
import { homeView } from "./views/home-view.js";
import { bindLoginForm, loginView } from "./views/login-view.js";
import { notFoundView } from "./views/not-found-view.js";
import { bindRegisterForm, registerView } from "./views/register-view.js";

const app = document.querySelector("#app");

registerRoute("/", homeView);
registerRoute("/login", loginView);
registerRoute("/register", registerView);
registerRoute("/elements", elementsView, requireLogin);
registerRoute("/elements/:atomicNumber", elementDetailsView, requireLogin);
registerRoute("/alloys", alloysView, requireLogin);
registerRoute("/alloys/:alloyId", alloyDetailsView, requireLogin);
registerRoute("/coins", coinsView, requireLogin);
registerRoute("/coins/:coinId", coinDetailsView, requireLogin);
registerRoute("/admin", adminHomeView, requireAdmin);
registerRoute("/admin/elements", elementsAdminView, requireAdmin);
registerRoute("/admin/alloys", alloysAdminView, requireAdmin);
registerRoute("/admin/coins", coinsAdminView, requireAdmin);
registerRoute("/admin/users", usersAdminView, requireAdmin);
registerRoute("/not-found", notFoundView);

registerRoute("/logout", () => {
  clearSession();
  window.location.hash = "/";
  return "";
});

function render(view) {
  app.innerHTML = `${navigation()}${view}`;
  bindLoginForm();
  bindRegisterForm();
  bindElementsView();
  bindElementDetailsView();
  bindAlloysView();
  bindAlloyDetailsView();
  bindCoinsView();
  bindCoinDetailsView();
  bindElementsAdminView();
  bindAlloysAdminView();
  bindCoinsAdminView();
  bindUsersAdminView();
}

await restoreSession();
startRouter(render);
