# Metals Atlas UI — Progress Checklist

This is the working implementation checklist for the client application. Items are checked off only after they are implemented and verified.

## Foundation

- [x] Create the framework-free project structure.
- [x] Add hash-based routing and route registration.
- [x] Add application state, session storage, and route guards.
- [x] Add a reusable API client and endpoint modules.
- [x] Add base components for navigation, alerts, loading states, form fields, and delete confirmation.

## Design system and assets

- [x] Define the visual direction in `theme-guidelines.yaml`.
- [x] Choose the subdued dark slate theme.
- [x] Create the refined foundry hero and catalog-card image assets.
- [x] Apply shared dark-theme tokens, typography, focus states, navigation, buttons, and responsive foundations.

## Home page

- [x] Build the home-page header and primary navigation.
- [x] Build the image-backed hero with title, description, and log-in action.
- [x] Build Elements, Alloys, and Coins catalog entry cards.
- [x] Add responsive home-page layouts.
- [x] Correct JavaScript module syntax and verify all UI modules parse.

## Authentication

- [x] Build the login form and client-side validation.
- [x] Connect login to `POST /api/auth/login`.
- [x] Store the returned session and update navigation after login.
- [x] Build the registration form and client-side validation.
- [x] Connect registration to `POST /api/auth/register`.
- [x] Add useful loading and API-error states.
- [x] Verify session restoration through `GET /api/auth/me`.
- [x] Add a registration link from the login screen.

## Customer catalog

**Status: Complete**

- [x] Build the Elements catalog view.
- [x] Load and render `GET /api/elements`.
- [x] Add element browsing/filtering and loading, empty, and error states.
- [x] Build an element detail view with `GET /api/elements/:atomicNumber`.
- [x] Build the Alloys catalog view.
- [x] Load and render `GET /api/alloys`.
- [x] Present alloy compositions when API data is available.
- [x] Build the Coins catalog view.
- [x] Load and render `GET /api/coins`.
- [x] Show the associated alloy for each coin.

## Administration

**Status: Complete**

- [x] Build the admin landing page with management links.
- [x] Build Elements create, edit, and delete workflows.
- [x] Build Alloys create, edit, and delete workflows.
- [x] Build Coins create, edit, and delete workflows.
- [x] Populate coin alloy selectors from the alloys endpoint.
- [x] Connect destructive actions to the delete confirmation dialog.
- [x] Surface field validation and API errors clearly.
- [x] Allow administrators to view users and manage administrator permission.

## Alloy composition

- [x] Confirm the `/api/alloy-elements` API contract.
- [ ] Build composition list and add/remove controls within alloy administration.
- [ ] Validate composition data and refresh affected alloy displays.

## Quality and release readiness

- [ ] Verify all routes at desktop and mobile widths.
- [ ] Verify keyboard navigation and visible focus states throughout.
- [ ] Review text and color contrast against the dark theme.
- [ ] Verify unauthenticated, Customer, and Admin permissions.
- [ ] Verify API errors and empty states using the live backend.
- [ ] Add deployment instructions and final API configuration notes.
