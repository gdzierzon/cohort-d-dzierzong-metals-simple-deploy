import { recordVisit } from "./navigation-history.js";

const routes = new Map();

export function registerRoute(path, view, guard = null) {
  routes.set(path, { view, guard });
}

export function navigate(path) {
  window.location.hash = path;
}

export function startRouter(render) {
  const resolveRoute = () => {
    const path = window.location.hash.slice(1) || "/";
    const route = findRoute(path) ?? { ...routes.get("/not-found"), params: {} };

    if (route.guard && !route.guard()) {
      navigate("/login");
      return;
    }

    // After the guard, so a route the visitor was bounced off never becomes the
    // page a "Back to ..." link offers. Before the view renders, because the view
    // reads the trail to build that link.
    recordVisit(path);

    render(route.view(route.params));
  };

  window.addEventListener("hashchange", resolveRoute);
  resolveRoute();
}

function findRoute(path) {
  const exactRoute = routes.get(path);
  if (exactRoute) return { ...exactRoute, params: {} };

  for (const [pattern, route] of routes) {
    if (!pattern.includes(":")) continue;
    const patternParts = pattern.split("/").filter(Boolean);
    const pathParts = path.split("/").filter(Boolean);
    if (patternParts.length !== pathParts.length) continue;

    const params = {};
    let matches = true;
    for (let index = 0; index < patternParts.length; index += 1) {
      if (patternParts[index].startsWith(":")) {
        try {
          params[patternParts[index].slice(1)] = decodeURIComponent(pathParts[index]);
        } catch {
          matches = false;
        }
      } else if (patternParts[index] !== pathParts[index]) {
        matches = false;
      }
    }
    if (matches) return { ...route, params };
  }
  return null;
}
