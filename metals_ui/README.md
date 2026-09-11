# Metals UI

The Metals UI is a framework-free, client-side JavaScript application for the Metals API. It uses native ES modules, hash-based routing, and the API's JWT Bearer-token authentication. The goal is a clear, approachable codebase that students can understand without React, Angular, or a build system.

## Product direction

Metals Atlas is a calm, educational catalog for metallurgy. It should celebrate the beauty of precious metals: molten gold and silver being poured into an ingot mold, polished alloy surfaces, and newly minted coins. The visual direction is refined and editorial rather than industrial.

The interface should use generous whitespace, restrained typography, limited decoration, and a small number of focused actions. A light and a subdued-dark concept have been created for comparison in the repository root as `metals-atlas-theme-comparison.png`.

## Roles and access

| Visitor type | Available actions |
| --- | --- |
| Unauthenticated visitor | View the home page, log in, or register. Catalog data is unavailable. |
| Customer | Browse elements, alloys, and coins. Cannot make catalog changes. |
| Admin | Browse the catalog and create, edit, or delete elements, alloys, and coins. |

The client uses route guards to guide users to the appropriate pages. The API remains the actual authorization boundary: it validates JWTs and enforces Customer/Admin access independently of the UI.

## Proposed routes

| Route | Audience | Purpose |
| --- | --- | --- |
| `#/` | Everyone | Landing page introducing the metallurgy catalog. |
| `#/login` | Unauthenticated visitor | Log in with an existing account. |
| `#/register` | Unauthenticated visitor | Create a Customer account. |
| `#/elements` | Customer or Admin | Browse and filter elements. |
| `#/alloys` | Customer or Admin | Browse alloys and their compositions. |
| `#/coins` | Customer or Admin | Browse coins and their alloy information. |
| `#/admin` | Admin | Administration landing page. |
| `#/admin/elements` | Admin | Create, edit, and delete elements. |
| `#/admin/alloys` | Admin | Create, edit, and delete alloys; later, manage compositions. |
| `#/admin/coins` | Admin | Create, edit, and delete coins. |
| `#/admin/users` | Admin | View users and manage administrator permission. |

Hash-based routes avoid server-side route-rewrite configuration and make the static client simple to deploy.

## Project structure

```text
metals_ui/
├── index.html
├── css/
│   ├── reset.css              # Browser-normalization rules
│   ├── variables.css          # Theme tokens
│   ├── layout.css             # Page and header layout
│   ├── components.css         # Shared control/card styles
│   └── pages.css              # Page-specific styles
├── js/
│   ├── app.js                 # App startup and route registration
│   ├── router.js              # Hash-route matching and navigation guards
│   ├── state.js               # Current user and role state
│   ├── config.js              # API base URL
│   ├── api/
│   │   ├── client.js          # fetch wrapper and Bearer-token support
│   │   ├── auth-api.js
│   │   ├── elements-api.js
│   │   ├── alloys-api.js
│   │   └── coins-api.js
│   ├── auth/
│   │   ├── session.js         # Token storage and session restoration
│   │   └── guards.js          # Customer/Admin route checks
│   ├── components/            # Shared navigation, alerts, forms, dialogs
│   └── views/
│       ├── catalog/           # Customer catalog views
│       └── admin/             # Admin-only management views
└── assets/
    └── images/                # Future logos, hero imagery, and visual assets
```

## Authentication behavior

- Login uses `POST /api/auth/login`.
- Registration uses `POST /api/auth/register`; the API always assigns the Customer role.
- The access token is kept in `sessionStorage`, so it remains available during page refreshes but is cleared when the browser session ends.
- On startup, the client calls `GET /api/auth/me` to restore the user and roles from a valid token.
- API requests automatically send `Authorization: Bearer <token>`.
- A `401 Unauthorized` response clears the local session and returns the user to login. A `403 Forbidden` response should display an access-denied message.

## API expectations

The UI uses the existing API endpoints:

- Authentication: `/api/auth/login`, `/api/auth/register`, `/api/auth/me`
- User administration: `GET /api/users`, `PUT /api/users/:userId/admin`
- Elements: `/api/elements`
- Alloys: `/api/alloys`
- Coins: `/api/coins`
- Alloy composition: `/api/alloy-elements` (planned for the alloy administration workflow)

Coins should use an alloy selection control populated from the alloys endpoint instead of requiring an administrator to type an alloy ID.

## Implementation phases

1. **Foundation** — static shell, neutral styles, router, navigation, session state, and API modules. This scaffold now exists.
2. **Authentication UI** — build login and registration forms, surface API validation errors, store tokens, and update navigation after login/logout.
3. **Customer catalog** — load elements, alloys, and coins; add accessible loading, empty, and error states; add basic browsing/filtering.
4. **Administration** — create list, form, edit, and delete workflows for elements, alloys, and coins; include delete confirmation.
5. **Alloy composition** — add composition management to alloy administration using `/api/alloy-elements`.
6. **Visual refinement** — choose light or subdued-dark direction, create a logo and imagery, build responsive layouts, and review accessibility.

## Development notes

### Run with Docker

From the repository root, start Docker Desktop in Linux container mode and run:

```powershell
docker compose up --build -d
```

Open `http://localhost:8888`. This starts the UI, API, and PostgreSQL services.
The root `.env` must provide `JWT_SECRET_KEY`, as described in the root README.
Set `UI_PORT` in that file if port 8888 is occupied.

The UI image uses Nginx as a non-root user on container port 8080. It serves
the HTML, CSS, JavaScript, and images; JavaScript executes in your browser.
The container's runtime configuration uses `/api`, which Nginx forwards to
`http://api:5000` over the Compose network. The browser needs only the UI URL.
The original `runtime-config.js` remains available for development outside Docker.

```powershell
docker compose logs -f ui
docker compose up --build -d ui
```

The second command rebuilds the UI after source changes. The UI health check
checks Nginx itself, not the API or database.

To build and run the UI separately against an API exposed on your Windows host:

```powershell
docker build -t metals-ui:1.0 ./metals_ui
docker run --name metals-ui -d -p 8888:8080 -e API_UPSTREAM=http://host.docker.internal:5000 metals-ui:1.0
```

Stop the Compose UI first if it already uses port 8888. For deployment, set
`API_UPSTREAM` to the API origin reachable from the UI container, including
`http://` or `https://`, without a trailing slash or `/api` suffix. The proxy
preserves the original `/api/...` path. Do not put secrets in browser configuration.

### Run without Docker

Serve this folder with any simple static web server during development. The
default local UI address is `http://localhost:8888`, and the API base URL is
configured independently in `runtime-config.js` (it defaults to
`http://localhost:5000/api`). Set `apiBaseUrl` in that file to the deployed API
URL for another environment. If the UI and Flask API use different origins,
the Flask API must allow the UI origin through CORS.

When rendering API data, build DOM nodes or safely escape text rather than injecting untrusted values into `innerHTML`.
